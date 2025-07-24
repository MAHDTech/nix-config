#!/usr/bin/env bash

set -euo pipefail

# Name: bootstrap-incus.sh
# Description: Bootstrap Incus nodes based on hostname.

##################################################
# Variables
##################################################

declare INCUS_NODENAME
INCUS_NODENAME=$(hostname)

declare -r INCUS_CLUSTER_BOOTSTRAP_NODE="hypervisor-1"
declare -r INCUS_CLUSTER_MEMBER_NODES=(
	"hypervisor-2"
	"hypervisor-3"
	"hypervisor-4"
)

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

# Passed via argument.
declare INCUS_CLUSTER_DESTROY=false

# The incus storage pools to destroy during cleanup.
declare -r INCUS_STORAGE_POOLS=(
	"default"
	"instances"
	"iso"
)

declare -r FIREWALL_PORTS=(
	"8443"
	"9443"
)

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

	return 0
}

function incus_bootstrap() {
	local NODE=$1
	local TYPE=$2

	case "${TYPE^^}" in

	"BOOTSTRAP")

		log "INFO" "Bootstrapping new incus cluster on node: ${NODE^^}"

		# Request join tokens for all member nodes.
		for NODE in "${INCUS_CLUSTER_MEMBER_NODES[@]}"; do
			log "INFO" "Requesting join token for node: ${NODE^^}"
			incus cluster add "${NODE^^}" --force-local 2>/dev/null || {
				log "ERROR" "Failed to request join token for node: ${NODE^^}"
				return 1
			}
		done

		log "WARN" "#################### IMPORTANT ####################"
		log "WARN" "Capture and save the join tokens for all nodes in the cluster"
		log "WARN" "#################### IMPORTANT ####################"

		read -rp "Press enter to continue..." || true

		;;

	"JOIN")

		log "WARN" "#################### IMPORTANT ####################"
		log "WARN" "If you haven't already, update the nix flake with the token for node ${NODE^^} now!"
		log "WARN" "#################### IMPORTANT ####################"

		read -rp "Press enter to continue..." || true

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
	incus network rm incusbr1 || true

	incus storage rm default || true

	return 0

}

function ovs_cleanup() {
	log "INFO" "Cleaning up Open vSwitch configuration..."

	log "INFO" "Restarting OVS services to ensure clean state..."
	sudo systemctl restart \
		ovs-vswitchd.service \
		ovsdb.service || {
		log "WARN" "Failed to restart some OVS services"
		return 1
	}
	sleep 10

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
		ovn-nb-ovsdb.service \
		ovn-northd.service \
		ovn-sb-ovsdb.service || {
		log "WARN" "Failed to stop some OVS services"
	}

	log "INFO" "Stopping OVS services..."
	sudo systemctl stop \
		ovs-vswitchd.service \
		ovsdb.service || {
		log "WARN" "Failed to stop some OVS services"
	}

	log "INFO" "Clearing OVS database..."
	sudo rm -f /var/lib/openvswitch/conf.db* || {
		log "WARN" "Failed to remove OVS database"
	}

	log "INFO" "Clearing OVS database..."
	sudo rm -f /etc/openvswitch/conf.db* || {
		log "WARN" "Failed to remove OVS database"
	}

	log "INFO" "Recreating OVS database..."

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

	log "INFO" "Starting OVS services..."
	sudo systemctl start \
		ovs-vswitchd.service \
		ovsdb.service || {
		log "WARN" "Failed to stop some OVS services"
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

	log "INFO" "Starting OVN services that interface with OVS..."
	sudo systemctl start \
		ovn-controller.service \
		ovn-nb-ovsdb.service \
		ovn-northd.service \
		ovn-sb-ovsdb.service || {
		log "WARN" "Failed to start some OVN services"
	}

	log "INFO" "Open vSwitch cleanup completed"
	return 0
}

function ovn_cleanup() {
	log "INFO" "Cleaning up Open Virtual Network configuration..."

	# Restart all OVN services first to ensure a clean state
	log "INFO" "Restarting OVN services..."
	sudo systemctl restart \
		ovn-controller.service \
		ovn-northd.service \
		ovn-nb-ovsdb.service \
		ovn-sb-ovsdb.service || {
		log "WARN" "Failed to restart some OVN services"
	}
	sleep 10

	# Get all logical switches and delete them
	for ls in $(sudo ovn-nbctl --timeout=10 ls-list 2>/dev/null | awk '{print $2}' | grep -v '^$' || true); do
		log "INFO" "Removing logical switch: $ls"
		sudo ovn-nbctl --timeout=10 --if-exists ls-del "$ls" || {
			log "WARN" "Failed to remove logical switch: $ls"
		}
	done

	# Get all logical routers and delete them
	log "INFO" "Removing all logical routers from OVN NB..."
	for lr in $(sudo ovn-nbctl --timeout=10 lr-list 2>/dev/null | awk '{print $2}' | grep -v '^$' || true); do
		log "INFO" "Removing logical router: $lr"
		sudo ovn-nbctl --timeout=10 --if-exists lr-del "$lr" || {
			log "WARN" "Failed to remove logical router: $lr"
		}
	done

	# Stop services for database recreation
	log "INFO" "Stopping OVN services for database cleanup..."
	sudo systemctl stop \
		ovn-controller.service \
		ovn-northd.service \
		ovn-nb-ovsdb.service \
		ovn-sb-ovsdb.service || {
		log "WARN" "Failed to stop some OVN services"
	}

	# Remove OVN database files completely
	log "INFO" "Removing OVN database files..."
	sudo rm -f /var/lib/ovn/ovnnb_db.db* || {
		log "WARN" "Failed to remove OVN NB database"
	}
	sudo rm -f /var/lib/ovn/ovnsb_db.db* || {
		log "WARN" "Failed to remove OVN SB database"
	}

	# Ensure OVN database directory exists
	sudo mkdir -p /var/lib/ovn || {
		log "ERROR" "Failed to create OVN database directory"
		return 1
	}

	# Find OVN schema files
	declare OVN_NB_SCHEMA_PATH OVN_SB_SCHEMA_PATH
	OVN_NB_SCHEMA_PATH=$(find /nix/store -name "ovn-nb.ovsschema" -path "*/share/ovn/*" 2>/dev/null | head -1) || {
		log "ERROR" "Could not find OVN NB schema file"
		return 1
	}
	OVN_SB_SCHEMA_PATH=$(find /nix/store -name "ovn-sb.ovsschema" -path "*/share/ovn/*" 2>/dev/null | head -1) || {
		log "ERROR" "Could not find OVN SB schema file"
		return 1
	}

	if [ "${OVN_NB_SCHEMA_PATH:-EMPTY}" = "EMPTY" ] || [ "${OVN_SB_SCHEMA_PATH:-EMPTY}" = "EMPTY" ]; then
		log "ERROR" "Could not find OVN schema files, unable to recreate the OVN databases"
		return 1
	fi

	log "DEBUG" "Using OVN NB schema: $OVN_NB_SCHEMA_PATH"
	log "DEBUG" "Using OVN SB schema: $OVN_SB_SCHEMA_PATH"

	# Recreate OVN databases
	log "INFO" "Recreating OVN NB database..."
	sudo ovsdb-tool create /var/lib/ovn/ovnnb_db.db "$OVN_NB_SCHEMA_PATH" || {
		log "ERROR" "Failed to create OVN NB database"
		return 1
	}

	log "INFO" "Recreating OVN SB database..."
	sudo ovsdb-tool create /var/lib/ovn/ovnsb_db.db "$OVN_SB_SCHEMA_PATH" || {
		log "ERROR" "Failed to create OVN SB database"
		return 1
	}

	# Restart all OVN services
	log "INFO" "Restarting OVN services..."
	sudo systemctl start \
		ovn-nb-ovsdb.service \
		ovn-sb-ovsdb.service \
		ovn-northd.service \
		ovn-controller.service || {
		log "WARN" "Failed to start some OVN services"
	}

	# Wait for OVN services to be ready
	log "INFO" "Waiting for OVN services to be ready..."
	for i in {1..30}; do
		if sudo ovn-nbctl --timeout=5 list nb_global >/dev/null 2>&1 &&
			sudo ovn-sbctl --timeout=5 list sb_global >/dev/null 2>&1; then
			log "INFO" "OVN services are ready!"
			break
		fi
		log "DEBUG" "Waiting for OVN services... ($i/30)"
		sleep 2
	done

	log "INFO" "Open Virtual Network cleanup completed"
	return 0
}

function network_services_cleanup() {
	log "INFO" "Performing network services cleanup..."

	log "INFO" "Performing Open Virtual Network cleanup..."
	ovn_cleanup || {
		log "ERROR" "OVN cleanup failed"
		return 1
	}

	log "INFO" "Performing Open vSwitch cleanup..."
	ovs_cleanup || {
		log "ERROR" "OVS cleanup failed"
		return 1
	}

	log "INFO" "Network services cleanup completed"
	return 0
}

function cleanup_verification() {
	log "INFO" "Verifying cleanup status..."

	# Check OVS bridges
	declare ovs_bridges_count
	ovs_bridges_count=$(sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list-br 2>/dev/null | wc -l || echo "0")
	if [ "$ovs_bridges_count" -eq 0 ]; then
		log "INFO" "✓ OVS bridges cleaned successfully"
	else
		declare remaining_bridges
		remaining_bridges=$(sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list-br 2>/dev/null | tr '\n' ' ' || echo "none")
		log "WARN" "Some OVS bridges still exist: $remaining_bridges"
	fi

	# Check OVN logical switches
	declare ovn_ls_count
	ovn_ls_count=$(sudo ovn-nbctl --timeout=5 ls-list 2>/dev/null | wc -l || echo "0")
	if [ "$ovn_ls_count" -eq 0 ]; then
		log "INFO" "✓ OVN logical switches cleaned successfully"
	else
		declare remaining_ls
		remaining_ls=$(sudo ovn-nbctl --timeout=5 ls-list 2>/dev/null | awk '{print $2}' | grep -v '^$' | tr '\n' ' ' || echo "none")
		log "WARN" "Some OVN logical switches still exist: $remaining_ls"
	fi

	# Check OVN logical routers
	declare ovn_lr_count
	ovn_lr_count=$(sudo ovn-nbctl --timeout=5 lr-list 2>/dev/null | wc -l || echo "0")
	if [ "$ovn_lr_count" -eq 0 ]; then
		log "INFO" "✓ OVN logical routers cleaned successfully"
	else
		declare remaining_lr
		remaining_lr=$(sudo ovn-nbctl --timeout=5 lr-list 2>/dev/null | awk '{print $2}' | grep -v '^$' | tr '\n' ' ' || echo "none")
		log "WARN" "Some OVN logical routers still exist: $remaining_lr"
	fi

	# Check OVN chassis entries
	declare chassis_count
	chassis_count=$(sudo ovn-sbctl --timeout=5 list chassis 2>/dev/null | grep -c "^_uuid" || echo "0")
	if [ "$chassis_count" -eq 0 ]; then
		log "INFO" "✓ No chassis entries found"
	else
		log "WARN" "Some chassis entries still exist (count: $chassis_count)"
	fi

	# Check Incus networks
	declare incus_networks_count
	incus_networks_count=$(incus query /1.0/networks 2>/dev/null | jq -r '.[]' | grep -c "incusbr" || echo "0")
	if [ "$incus_networks_count" -eq 0 ]; then
		log "INFO" "✓ Incus networks cleaned successfully"
	else
		log "WARN" "Some Incus networks still exist"
	fi

	log "INFO" "Cleanup verification completed"
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

	sudo systemctl stop \
		incus-preseed.service \
		incus.service \
		incus.socket || {
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
		sudo zfs destroy -r "${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS}/${POOL}" || {
			log "WARN" "Failed to remove incus storage pool: ${POOL} in ZFS Dataset: ${ZFS_DATASET_NAME_INCUS_STORAGE_POOLS}"
		}

		if [[ -d "${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${POOL}" ]]; then
			log "INFO" "Removing incus directory: ${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${POOL}"
			sudo rm -rf "${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${POOL}" || {
				log "WARN" "Failed to remove incus directory: ${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${POOL}"
			}
		else
			log "INFO" "No incus directory found for pool ${POOL} at path: ${ZFS_DATASET_PATH_INCUS_STORAGE_POOLS}/${POOL}, skipping removal"
		fi

	done

	log "INFO" "Removing incus database files..."

	sudo rm -rf /var/lib/incus/database/{global,local.db} || {
		log "ERROR" "Failed to remove database files"
		return 1
	}

	# Verify the database files were removed
	if [[ -f /var/lib/incus/database/global ]] ||
		[[ -f /var/lib/incus/database/local.db ]]; then
		log "ERROR" "Database files still exist"
		exit 1
	fi

	log "INFO" "Removing incus certificates..."

	sudo rm -rf /var/lib/incus/{cluster.crt,cluster.key,server.crt,server.key} || {
		log "ERROR" "Failed to remove incus certificates"
		return 1
	}

	# Verify cleanup was successful
	cleanup_verification || {
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

##################################################
# Pre-flight checks
##################################################

log "INFO" "Starting bootstrap process for node: ${INCUS_NODENAME^^}"

parse_flags "$@" || {
	log "ERROR" "Failed to parse flags"
	exit 1
}

check_for_required_tools || {
	log "ERROR" "Required tools not found"
	exit 1
}

##################################################
# Main
##################################################

if [[ ${INCUS_CLUSTER_DESTROY^^} == "TRUE" ]]; then
	incus_destroy_cluster || {
		log "ERROR" "Failed to destroy incus cluster"
		exit 1
	}

	log "INFO" "The incus cluster has been destroyed. Please unset the INCUS_CLUSTER_DESTROY variable and re-run the script to bootstrap a new cluster."
	exit 0
fi

# If this node is the bootstrap node, bootstrap the cluster.
if [[ ${INCUS_NODENAME^^} == "${INCUS_CLUSTER_BOOTSTRAP_NODE^^}" ]]; then

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
		log "WARN" "#################### IMPORTANT ####################"
		log "WARN" "You seem to be missing a firewall rule to allow TCP ${PORT} traffic. Don't forget to add it!"
		log "WARN" "#################### IMPORTANT ####################"
	}
done

log "INFO" "Bootstrap complete for node: ${INCUS_NODENAME^^}"
