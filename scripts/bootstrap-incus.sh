#!/usr/bin/env bash

set -euo pipefail

# Name: bootstrap-incus.sh
# Description: Bootstrap Incus nodes based on hostname.

#########################
# Variables
#########################

declare INCUS_NODENAME
INCUS_NODENAME=$(hostname)

declare -r INCUS_CLUSTER_BOOTSTRAP_NODE="hypervisor-1"
declare -r INCUS_CLUSTER_MEMBER_NODES=(
	"hypervisor-2"
	"hypervisor-3"
	"hypervisor-4"
)

declare -r ZFS_POOL_NAME="zpool"
declare -r ZFS_DATASET_NAME="zpool/var/lib/incus/storage-pools"
declare -r ZFS_DATASET_PATH="${ZFS_DATASET_NAME#"${ZFS_POOL_NAME}"}"

# Passed via argument.
declare INCUS_CLUSTER_DESTROY=false

declare -r INCUS_STORAGE_POOLS=(
	"default"
	"instances"
	"iso"
)

declare -r FIREWALL_PORTS=(
	"8443"
	"9443"
)

#########################
# Functions
#########################

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

function incus_check() {
	local INCUS_TOOLS=(
		"incus"
	)

	# Make sure we have the required incus tools available.
	for TOOL in "${INCUS_TOOLS[@]}"; do
		if ! command -v "${TOOL}" &>/dev/null; then
			log "ERROR" "Required Incus tool not found: ${TOOL}"
			return 1
		fi
	done

	return 0
}

function network_tools_check() {
	local NETWORK_TOOLS=(
		"ovs-vsctl"
		"ovn-nbctl"
		"ovn-sbctl"
	)

	# Make sure we have the required network tools available.
	for TOOL in "${NETWORK_TOOLS[@]}"; do
		if ! command -v "${TOOL}" &>/dev/null; then
			log "WARN" "Network tool not found: ${TOOL} (network cleanup may be limited)"
		fi
	done

	return 0
}

function incus_bootstrap() {
	local NODE=$1
	local TYPE=$2

	case "${TYPE^^}" in

	"BOOTSTRAP")
		log "INFO" "Bootstrapping new incus cluster on node: ${NODE^^}"

		# Preseed is automatically applied NixOS, restart the service to ensure it's been run.
		log "INFO" "Pre-seeding the incus cluster..."
		sudo systemctl restart incus-preseed || {
			log "ERROR" "Failed to run incus-preseed"
			journalctl -u incus-preseed -n 25 -o cat --no-pager
			return 1
		}
		sleep 30

		# Request join tokens for all member nodes.
		for NODE in "${INCUS_CLUSTER_MEMBER_NODES[@]}"; do
			log "INFO" "Requesting join token for node: ${NODE^^}"
			incus cluster add "${NODE^^}" --force-local 2>/dev/null || {
				log "ERROR" "Failed to request join token for node: ${NODE^^}"
				return 1
			}
		done

		log "WARN" "##### IMPORTANT #####"
		log "WARN" "Capture and save the join tokens for all nodes in the cluster."
		log "WARN" "##### IMPORTANT #####"

		;;

	"JOIN")
		log "WARN" "##### IMPORTANT #####"
		log "WARN" "Capture the token in the output from ${INCUS_CLUSTER_BOOTSTRAP_NODE^^} and update the nix flake for node: ${NODE^^}" log "WARN" "##### IMPORTANT #####"
		log "WARN" "##### IMPORTANT #####"

		;;
	esac

	return 0
}

function incus_cleanup() {

	log "INFO" "Stopping all incus containers..."

	incus stop --all

	log "INFO" "Cleaning up incus configuration..."

	incus profile device rm default root || true
	incus profile device rm default eth0 || true
	incus network rm incusbr0 || true
	incus storage rm default || true

	return 0

}

function ovs_cleanup() {
	log "INFO" "Cleaning up OpenVSwitch configuration..."

	# Stop OVS services temporarily for clean reset
	log "INFO" "Stopping OVS services for cleanup..."
	sudo systemctl stop \
		ovn-controller.service \
		ovn-nb-ovsdb.service \
		ovn-northd.service \
		ovn-sb-ovsdb.service \
		ovs-vswitchd.service \
		ovsdb.service ||
		{
			log "WARN" "Failed to stop some OVS services"
		}

	# Remove all bridges.
	for bridge in $(sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list-br 2>/dev/null || true); do
		log "DEBUG" "Deleting bridge: $bridge"
		sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock --if-exists del-br "$bridge"
	done

	# Clear external_ids that might interfere with OVN
	sudo ovs-vsctl --if-exists clear open_vswitch . external_ids || {
		log "WARN" "Failed to clear OVS external_ids"
	}

	# Remove any existing ports that might conflict
	log "INFO" "Removing any residual OVS ports..."
	sudo ovs-vsctl --if-exists del-port bond0 || {
		log "DEBUG" "No bond0 port to remove from OVS"
	}

	# Clear any manager connections
	sudo ovs-vsctl --if-exists clear open_vswitch . manager_options || {
		log "WARN" "Failed to clear OVS manager options"
	}

	# Clear the OVS database.
	sudo rm -f /var/lib/openvswitch/conf.db* || {
		log "WARN" "Failed to remove OVS database"
	}
	sudo rm -f /etc/openvswitch/conf.db* || {
		log "WARN" "Failed to remove OVS database"
	}

	# Re-create the OVS database.
	log "INFO" "Recreating OVS database..."

	# Ensure the directory exists
	sudo mkdir -p /var/lib/openvswitch || {
		log "ERROR" "Failed to create OVS database directory"
		return 1
	}

	declare OVS_SCHEMA_PATH
	OVS_SCHEMA_PATH=$(find /nix/store -name "vswitch.ovsschema" -path "*/share/openvswitch/*" 2>/dev/null | head -1) || {
		log "ERROR" "Could not find OVS schema file"
		return 1
	}

	if [ "${OVS_SCHEMA_PATH:-EMPTY}" = "EMPTY" ]; then
		log "ERROR" "Could not find OVS schema file, unable to recreate the OVS database"
		exit 1
	fi

	log "DEBUG" "Using schema: $OVS_SCHEMA_PATH"
	sudo ovsdb-tool create /var/lib/openvswitch/conf.db "$OVS_SCHEMA_PATH" || {
		log "ERROR" "Failed to create OVS database"
		exit 1
	}

	# Restart OVS services with clean state
	log "INFO" "Restarting OVS services..."
	sudo systemctl start \
		ovn-controller.service \
		ovn-nb-ovsdb.service \
		ovn-northd.service \
		ovn-sb-ovsdb.service \
		ovs-vswitchd.service \
		ovsdb.service ||
		{
			log "WARN" "Failed to restart some OVS services"
		}

	# Wait for OVS services to be ready.
	for i in {1..30}; do
		if sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock show >/dev/null 2>&1; then
			log "INFO" "OVS is ready!"
			break
		fi
		log "DEBUG" "Waiting... ($i/30)"
		sleep 3
	done

	# Set fresh external_ids for the hypervisor
	sudo ovs-vsctl set open_vswitch . "external_ids:system-id=$(hostname)" || {
		log "WARN" "Failed to set system-id in OVS"
	}

	log "INFO" "OpenVSwitch cleanup completed"
	return 0
}

function ovn_cleanup() {
	log "INFO" "Cleaning up Open Virtual Network configuration..."

	# Stop OVN services to prevent interference (if they exist and are running)
	if systemctl is-active --quiet ovn-controller.service 2>/dev/null; then
		sudo systemctl stop ovn-controller.service || {
			log "WARN" "Failed to stop ovn-controller service"
		}
	else
		log "DEBUG" "ovn-controller.service not running, skipping stop"
	fi

	if systemctl is-active --quiet ovn-northd.service 2>/dev/null; then
		sudo systemctl stop ovn-northd.service || {
			log "WARN" "Failed to stop ovn-northd service"
		}
	else
		log "DEBUG" "ovn-northd.service not running, skipping stop"
	fi

	# Clear OVN databases
	log "INFO" "Clearing OVN Northbound database..."
	sudo ovn-nbctl --if-exists ls-del incusbr0 || {
		log "WARN" "Failed to remove incusbr0 logical switch from OVN NB"
	}

	# Remove chassis from southbound database
	log "INFO" "Clearing OVN Southbound chassis entries..."
	sudo ovn-sbctl --if-exists chassis-del "$(hostname)" || {
		log "WARN" "Failed to remove chassis from OVN SB"
	}

	# Restart OVN services to get clean state
	log "INFO" "Restarting OVN services for clean state..."
	sudo systemctl start ovn-nb-ovsdb.service ovn-sb-ovsdb.service || {
		log "WARN" "Failed to start OVN database services"
	}

	sleep 5

	# Only start services if they are enabled
	if systemctl is-enabled ovn-northd.service &>/dev/null; then
		sudo systemctl start ovn-northd.service || {
			log "WARN" "Failed to start ovn-northd service"
		}
	else
		log "DEBUG" "ovn-northd.service not enabled, skipping start"
	fi

	if systemctl is-enabled ovn-controller.service &>/dev/null; then
		sudo systemctl start ovn-controller.service || {
			log "WARN" "Failed to start ovn-controller service"
		}
	else
		log "DEBUG" "ovn-controller.service not enabled, skipping start"
	fi

	log "INFO" "Open Virtual Network cleanup completed"
	return 0
}

function network_services_cleanup() {
	log "INFO" "Performing network services cleanup..."

	# Stop Incus to prevent conflicts
	sudo systemctl stop incus.service incus-preseed.service incus.socket || {
		log "WARN" "Failed to stop some Incus services"
	}

	# Perform OVS cleanup
	ovs_cleanup || {
		log "ERROR" "OVS cleanup failed"
		return 1
	}

	# Perform OVN cleanup
	ovn_cleanup || {
		log "ERROR" "OVN cleanup failed"
		return 1
	}

	log "INFO" "Network services cleanup completed"
	return 0
}

function verify_cleanup() {
	log "INFO" "Verifying cleanup status..."

	# Check OVS bridges
	local OVS_BRIDGES
	OVS_BRIDGES=$(sudo ovs-vsctl list-br 2>/dev/null | grep -E "incusbr0|br-int" || true)
	if [[ -n ${OVS_BRIDGES} ]]; then
		log "WARN" "Some OVS bridges still exist: ${OVS_BRIDGES}"
	else
		log "INFO" "✓ OVS bridges cleaned successfully"
	fi

	# Check OVN logical switches
	local OVN_SWITCHES
	OVN_SWITCHES=$(sudo ovn-nbctl ls-list 2>/dev/null | grep incusbr0 || true)
	if [[ -n ${OVN_SWITCHES} ]]; then
		log "WARN" "Some OVN logical switches still exist: ${OVN_SWITCHES}"
	else
		log "INFO" "✓ OVN logical switches cleaned successfully"
	fi

	# Check for chassis entries
	local CHASSIS_ENTRIES
	CHASSIS_ENTRIES=$(sudo ovn-sbctl chassis-list 2>/dev/null | grep "$(hostname)" || true)
	if [[ -n ${CHASSIS_ENTRIES} ]]; then
		log "INFO" "✓ Chassis entry exists (expected for active node): $(hostname)"
	else
		log "INFO" "✓ No chassis entries found"
	fi

	# Check Incus network state
	local INCUS_NETWORKS
	INCUS_NETWORKS=$(incus network list --format compact 2>/dev/null | grep incusbr0 || true)
	if [[ -n ${INCUS_NETWORKS} ]]; then
		log "WARN" "Incus network still exists: ${INCUS_NETWORKS}"
	else
		log "INFO" "✓ Incus networks cleaned successfully"
	fi

	log "INFO" "Cleanup verification completed"
	return 0
}

function incus_destroy_cluster() {
	local FOUND_BOOTSTRAP_NODE=false

	incus_cleanup || {
		log "ERROR" "Failed to cleanup incus"
		return 1
	}

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
		incus cluster remove --force "${NODE^^}" || {
			log "WARN" "Failed to remove incus node: ${NODE^^}"
		}
	done

	# Now that all member nodes have been removed, remove the bootstrap server.
	if [[ ${FOUND_BOOTSTRAP_NODE^^} == "TRUE" ]]; then
		log "WARN" "Removing bootstrap server: ${INCUS_NODENAME^^}"
		incus cluster remove --force "${INCUS_NODENAME^^}" || {
			log "WARN" "Failed to remove bootstrap server: ${INCUS_NODENAME^^}"
		}
	fi

	log "INFO" "Stopping incus services..."

	sudo systemctl stop incus.service incus-preseed.service incus.socket || {
		log "ERROR" "Failed to stop incus services"
		return 1
	}

	# Perform network services cleanup (OVS/OVN)
	network_services_cleanup || {
		log "ERROR" "Failed to cleanup network services"
		return 1
	}

	log "INFO" "Removing incus storage pools..."

	for POOL in "${INCUS_STORAGE_POOLS[@]}"; do
		log "INFO" "Removing incus storage pool: ${POOL}"
		sudo zfs destroy -r "${ZFS_DATASET_NAME}/${POOL}" || {
			log "WARN" "Failed to remove incus storage pool: ${POOL} in ZFS Dataset: ${ZFS_DATASET_NAME}"
		}

		if [[ -d "${ZFS_DATASET_PATH}/${POOL}" ]]; then
			log "INFO" "Removing incus directory: ${ZFS_DATASET_PATH}/${POOL}"
			sudo rm -rf "${ZFS_DATASET_PATH}/${POOL}" || {
				log "WARN" "Failed to remove incus directory: ${ZFS_DATASET_PATH}/${POOL}"
			}
		else
			log "INFO" "No incus directory found for pool ${POOL} at path: ${ZFS_DATASET_PATH}/${POOL}, skipping removal"
		fi

	done

	log "INFO" "Removing incus database files..."

	sudo rm -rf /var/lib/incus/database/{global,local.db} || {
		log "ERROR" "Failed to remove database files"
		return 1
	}

	log "INFO" "Removing incus certificates..."

	sudo rm -rf /var/lib/incus/{cluster.crt,cluster.key,server.crt,server.key} || {
		log "ERROR" "Failed to remove incus certificates"
		return 1
	}

	# Verify cleanup was successful
	verify_cleanup || {
		log "WARN" "Cleanup verification encountered issues"
	}

	return 0

}

function parse_flags() {
	local FLAGS=("$@")

	for FLAG in "${FLAGS[@]}"; do

		log "DEBUG" "Parsing flag: ${FLAG}"

		case "${FLAG,,}" in

		"--incus-destroy-cluster")

			INCUS_CLUSTER_DESTROY=true
			log "WARN" "Incus cluster destruction is enabled"

			;;

		*)

			log "WARN" "Unknown flag: ${FLAG}"
			exit 1

			;;

		esac

	done

	return 0
}

#########################
# Pre-flight checks
#########################

log "INFO" "Starting bootstrap process for node: ${INCUS_NODENAME^^}"

parse_flags "$@" || {
	log "ERROR" "Failed to parse flags"
	exit 1
}

incus_check || {
	log "ERROR" "Incus tools not found"
	exit 1
}

network_tools_check || {
	log "WARN" "Some network tools not found, cleanup may be limited"
}

if [[ ${INCUS_CLUSTER_DESTROY^^} == "TRUE" ]]; then
	incus_destroy_cluster || {
		log "ERROR" "Failed to destroy incus cluster"
		exit 1
	}

	log "INFO" "The incus cluster has been destroyed. Please unset the INCUS_CLUSTER_DESTROY variable and re-run the script to bootstrap a new cluster."
	exit 0
fi

#########################
# Main
#########################

# If this node is the bootstrap node, bootstrap the cluster.
if [[ ${INCUS_NODENAME^^} == "${INCUS_CLUSTER_BOOTSTRAP_NODE^^}" ]]; then
	log "INFO" "Bootstrapping new incus cluster from node: ${INCUS_NODENAME^^}"

	incus_bootstrap "$INCUS_NODENAME" "BOOTSTRAP" || {
		log "ERROR" "Failed to bootstrap cluster on node: ${INCUS_NODENAME^^}"
		exit 1
	}

else

	# If this node is one of the member nodes, join the cluster.
	MATCH=false
	for NODE in "${INCUS_CLUSTER_MEMBER_NODES[@]}"; do
		if [[ ${INCUS_NODENAME^^} == "${NODE^^}" ]]; then
			log "INFO" "Joining incus cluster on node: ${INCUS_NODENAME^^} as a member node"

			incus_bootstrap "$INCUS_NODENAME" "JOIN" || {
				log "ERROR" "Failed to join cluster on node: ${INCUS_NODENAME^^}"
				exit 1
			}
			MATCH=true
		fi
	done

	if [[ ${MATCH^^} == "FALSE" ]]; then
		log "WARN" "Skipping cluster join for unknown node: ${INCUS_NODENAME^^}"
		exit 1
	fi

fi

for PORT in "${FIREWALL_PORTS[@]}"; do
	log "INFO" "Verifying firewall port ${PORT}"
	sudo nft list ruleset | grep -q "${PORT}" || {
		log "WARN" "##### IMPORTANT #####"
		log "WARN" "You seem to be missing a firewall rule to allow TCP ${PORT} traffic. Don't forget to add it!"
		log "WARN" "##### IMPORTANT #####"
	}
done

log "INFO" "Bootstrap complete for node: ${INCUS_NODENAME^^}"
