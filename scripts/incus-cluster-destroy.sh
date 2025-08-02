#!/usr/bin/env bash

set -euo pipefail

# Name: incus-cluster-destroy.sh
# Description: Destroy Incus cluster on nodes.
# Version: 2.0

##################################################
# Variables
##################################################

declare INCUS_NODENAME
INCUS_NODENAME=$(hostname)

declare -r INCUS_CLUSTER_BOOTSTRAP_NODE="hypervisor-1"

declare -r REQUIRED_TOOLS=(
	"incus"
	"jq"
	"ovn-nbctl"
	"ovn-sbctl"
	"ovs-vsctl"
)

# The ZFS pool name.
declare -r ZFS_POOL_NAME="zpool"

# The ZFS dataset names
declare -r ZFS_DATASET_NAME_INCUS="${ZFS_POOL_NAME}/var/lib/incus"
declare -r ZFS_DATASET_NAME_INCUS_STORAGE_POOLS="${ZFS_DATASET_NAME_INCUS}/storage-pools"

# The path where the ZFS dataset is mounted.
declare -r ZFS_DATASET_PATH_INCUS_STORAGE_POOLS="${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS#"${ZFS_POOL_NAME}"}"

# The ZFS dataset names that will be destroyed during cleanup.
# These can also be pools if created in error.
declare -r ZFS_DATASET_NAMES_INCUS_STORAGE_POOLS=(
	"default"
	"instances"
	"iso"
)

# OVN database file paths
declare -r OVN_NB_DB_FILE="/var/lib/ovn/ovnnb_db.db"
declare -r OVN_SB_DB_FILE="/var/lib/ovn/ovnsb_db.db"

# Script start time for timing
SCRIPT_START_TIME=$(date +%s)

##################################################
# Functions
##################################################

function log() {
	local LEVEL="${1}"
	local MESSAGE="${2}"

	case "${LEVEL^^}" in
	"DEBUG")
		echo -e "\033[34m${MESSAGE}\033[0m"
		;;
	"INFO")
		echo -e "\033[32m${MESSAGE}\033[0m"
		;;
	"WARN")
		echo -e "\033[33m${MESSAGE}\033[0m"
		;;
	"ERROR")
		echo -e "\033[31m${MESSAGE}\033[0m"
		;;
	*)
		echo -e "${MESSAGE}"
		;;
	esac

	return 0
}

function check_for_required_tools() {

	# Make sure we have the required tools available in the PATH.
	for TOOL in "${REQUIRED_TOOLS[@]}"; do
		if ! command -v "${TOOL}" &>/dev/null; then
			log "ERROR" "Required tool not found: ${TOOL}"
			return 1
		fi
	done

	# Additional check for OVS/OVN tools
	if ! command -v ovsdb-tool &>/dev/null; then
		log "ERROR" "Required tool not found: ovsdb-tool"
		return 1
	fi

	return 0
}

function validate_environment() {
	log "INFO" "Validating environment..."

	# Check if we're running as root or with sudo
	if [[ ${EUID} -ne 0 ]] && ! sudo -n true 2>/dev/null; then
		log "ERROR" "This script requires sudo privileges"
		return 1
	fi

	# Check if we're on a hypervisor
	if [[ ! ${INCUS_NODENAME} =~ ^hypervisor-[1-4]$ ]]; then
		log "WARN" "This script is designed for hypervisor nodes, running on: ${INCUS_NODENAME}"
	fi

	return 0
}

function emergency_cleanup() {
	log "WARN" "Performing emergency cleanup..."

	# Stop all services to prevent further issues
	sudo systemctl stop \
		incus-preseed.service \
		incus-startup.service \
		incus.service \
		incus.socket \
		ovn-controller.service \
		ovn-central.service \
		ovn-northbound-db.service \
		ovn-southbound-db.service \
		ovs-vswitchd.service \
		ovsdb.service || true

	log "WARN" "Emergency cleanup completed"

	return 0
}

function cleanup_incus() {

	if ! incus info >/dev/null 2>&1; then
		log "WARN" "Incus daemon is not running, skipping cleanup of Incus resources."
		return 0
	fi

	log "INFO" "Stopping all incus containers..."

	incus stop --all --force-local --timeout=300 || {
		log "WARN" "Failed to stop all incus containers"
	}

	log "INFO" "Cleaning up incus configuration..."

	incus profile device remove default root || true
	incus profile device remove default eth0 || true

	incus network delete incusbr0 || true
	incus network delete incusbr1 || true

	incus storage delete default || true
	incus storage delete instances || true
	incus storage delete iso || true

	return 0

}

function cleanup_incus_cluster() {
	local FOUND_BOOTSTRAP_NODE=false

	log "INFO" "Removing all incus nodes from cluster..."

	local INCUS_CLUSTER_NODES=()
	mapfile -t INCUS_CLUSTER_NODES < <(incus cluster list --format compact,noheader --columns n)

	for NODE in "${INCUS_CLUSTER_NODES[@]}"; do
		# Trim all whitespace from the node name.
		NODE=$(echo "${NODE}" | xargs)

		# The bootstrap server must be removed last.
		if [[ ${NODE^^} == "${INCUS_CLUSTER_BOOTSTRAP_NODE^^}" ]]; then
			log "WARN" "Skipping removal of bootstrap server: ${NODE^^}"
			FOUND_BOOTSTRAP_NODE=true
			continue
		fi

		log "WARN" "Removing incus node: ${NODE^^}"
		incus cluster remove --yes --force "${NODE^^}" || {
			log "WARN" "Failed to remove incus node: ${NODE^^}"
		}
	done

	# Now that all member nodes have been removed, remove the bootstrap server.
	if [[ ${FOUND_BOOTSTRAP_NODE^^} == "TRUE" ]]; then
		log "WARN" "Removing bootstrap server: ${INCUS_NODENAME^^}"
		incus cluster remove --yes --force "${INCUS_NODENAME^^}" || {
			log "WARN" "Failed to remove bootstrap server: ${INCUS_NODENAME^^}"
		}
	fi

	log "INFO" "Stopping all incus services..."

	# Stop Incus completely
	sudo systemctl stop \
		incus-preseed.service \
		incus-startup.service \
		incus.service \
		incus.socket || true

	log "INFO" "Removing incus storage pools..."

	zfs_cleanup || {
		log "ERROR" "Failed to cleanup ZFS"
		return 1
	}

	log "INFO" "Removing incus database files..."

	sudo rm -rf /var/lib/incus/database || {
		log "ERROR" "Failed to remove database files"
		return 1
	}

	# Verify the database files were removed
	if [[ -f /var/lib/incus/database/global ]] ||
		[[ -f /var/lib/incus/database/local.db ]]; then
		log "ERROR" "Database files still exist"
		return 1
	fi

	log "INFO" "Removing incus certificates..."

	sudo rm -rf /var/lib/incus/{cluster.*,server.*} || {
		log "ERROR" "Failed to remove incus certificates"
		return 1
	}

	return 0

}

function zfs_cleanup() {
	log "INFO" "Performing ZFS cleanup..."

	# For each ZFS dataset name, recursively destroy the ZFS dataset.
	for ZFS_DATASET_NAME in "${ZFS_DATASET_NAMES_INCUS_STORAGE_POOLS[@]}"; do

		# If the ZFS dataset exists, destroy it recursively.
		if sudo zfs list "${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}" >/dev/null 2>&1; then
			log "INFO" "Destroying ZFS dataset: ${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}"
			sudo zfs destroy -rf "${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}" || {
				log "WARN" "Failed to destroy ZFS dataset: ${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}"
			}
		fi

		# If the mount point exists, remove the folder
		if [[ -d "${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}" ]]; then
			log "INFO" "Removing mount point: ${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}"
			sudo rm -rf "${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}" || {
				log "WARN" "Failed to remove mount point: ${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${ZFS_DATASET_NAME}"
			}
		fi

	done

	# If there was a mistake during the creation of the cluster
	# Then pools may have been created instead of datasets.
	# If any of these exist as pools, when they should be datasets, destroy them.
	for ZPOOL in "${ZFS_DATASET_NAMES_INCUS_STORAGE_POOLS[@]}"; do
		if sudo zpool status "${ZPOOL}" >/dev/null 2>&1; then
			log "INFO" "Destroying ZFS pool: ${ZPOOL}"
			sudo zpool destroy -f "${ZPOOL}" || {
				log "WARN" "Failed to destroy ZFS pool: ${ZPOOL}"
			}
		else
			log "DEBUG" "ZFS pool does not exist: ${ZPOOL}"
		fi
	done

	return 0
}

function cleanup_ovn() {
	log "INFO" "Cleaning up OVN databases..."

	log "INFO" "Using NB database: ${OVN_NB_DB_FILE}"
	log "INFO" "Using SB database: ${OVN_SB_DB_FILE}"

	# Stop OVN services to work with databases
	sudo systemctl stop ovn-controller ovn-central ovn-northbound-db ovn-southbound-db || {
		log "WARN" "Failed to stop some OVN services"
	}

	# Remove all database files - let systemd recreate them automatically
	sudo rm -f "${OVN_NB_DB_FILE}" "${OVN_SB_DB_FILE}" || {
		log "WARN" "Failed to remove existing OVN database files"
	}

	# Remove any leftover database files
	sudo rm -f /var/lib/ovn/ovn* /var/lib/ovn/.ovn* || {
		log "WARN" "Failed to remove leftover OVN database files"
	}

	log "INFO" "OVN databases cleaned up"
	return 0
}

function cleanup_ovs() {
	log "INFO" "Cleaning up Open vSwitch configuration..."

	log "INFO" "Restarting OVS services to ensure clean state..."
	sudo systemctl restart \
		ovs-vswitchd.service \
		ovsdb.service || {
		log "WARN" "Failed to restart some OVS services"
		return 1
	}
	sleep 30

	log "INFO" "Removing all OVS bridges..."
	for bridge in $(sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list-br 2>/dev/null || true); do
		log "INFO" "Deleting bridge: $bridge"
		sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock --if-exists del-br "$bridge"
	done

	log "INFO" "Clearing OVS external_ids..."
	sudo ovs-vsctl --if-exists clear open_vswitch . external_ids || {
		log "WARN" "Failed to clear OVS external_ids"
	}

	log "INFO" "Removing any residual OVS ports..."
	sudo ovs-vsctl --if-exists del-port bond0 || {
		log "DEBUG" "No bond0 port to remove from OVS"
	}

	log "INFO" "Clearing OVS manager options..."
	sudo ovs-vsctl --if-exists clear open_vswitch . manager_options || {
		log "WARN" "Failed to clear OVS manager options"
	}

	log "INFO" "Stopping OVN services that interface with OVS..."
	sudo systemctl stop \
		ovn-controller.service \
		ovn-northbound-db.service \
		ovn-central.service \
		ovn-southbound-db.service || {
		log "WARN" "Failed to stop some OVS services"
	}

	log "INFO" "Stopping OVS services..."
	sudo systemctl stop \
		ovs-vswitchd.service \
		ovsdb.service || {
		log "WARN" "Failed to stop some OVS services"
	}

	# Remove existing database
	sudo rm -f /var/lib/openvswitch/conf.db* || {
		log "WARN" "Failed to remove existing OVS database"
	}

	log "INFO" "Open vSwitch cleanup completed"
	return 0
}

function show_summary() {
	local END_TIME
	END_TIME=$(date +%s)
	local DURATION=$((END_TIME - SCRIPT_START_TIME))

	log "INFO" "=== Cleanup Summary ==="
	log "INFO" "Node: ${INCUS_NODENAME^^}"
	log "INFO" "Duration: ${DURATION} seconds"
	log "INFO" "Steps completed: ${CLEANUP_STEPS[*]}"
	log "INFO" "Status: SUCCESS"
	log "INFO" "======================"
}

##################################################
# Main
##################################################

# Set up trap for emergency cleanup on script exit
trap 'emergency_cleanup' EXIT

log "INFO" "Starting incus cluster destruction for node: ${INCUS_NODENAME^^}"

check_for_required_tools || {
	log "ERROR" "Required tools not found"
	exit 1
}

validate_environment || {
	log "ERROR" "Environment validation failed"
	exit 2
}

# Track cleanup steps
CLEANUP_STEPS=()

if cleanup_incus; then
	CLEANUP_STEPS+=("incus")
else
	log "ERROR" "Failed to cleanup incus"
	exit 3
fi

if cleanup_incus_cluster; then
	CLEANUP_STEPS+=("cluster")
else
	log "ERROR" "Failed to destroy incus cluster"
	exit 4
fi

if cleanup_ovn; then
	CLEANUP_STEPS+=("ovn")
else
	log "ERROR" "Failed to cleanup OVN"
	exit 5
fi

if cleanup_ovs; then
	CLEANUP_STEPS+=("ovs")
else
	log "ERROR" "Failed to cleanup OVS"
	exit 6
fi

# Remove the trap since we're good to go!
trap - EXIT

log "INFO" "The incus cluster has been destroyed on node: ${INCUS_NODENAME^^}."
show_summary
