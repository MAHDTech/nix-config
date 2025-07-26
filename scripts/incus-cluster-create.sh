#!/usr/bin/env bash

set -euo pipefail

# Name: incus-cluster-create.sh
# Description: Create Incus cluster on nodes.

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

		cat <<-EOF
			##################################################
			                    IMPORTANT
			##################################################

			Capture and save the join tokens for all nodes in the cluster

			##################################################
		EOF
		read -rp "Press enter to continue..." || true

		;;

	"JOIN")

		log "INFO" "Joining is now performed by incus-preseed automatically."

		;;
	esac

	return 0
}

##################################################
# Main
##################################################

log "INFO" "Starting incus cluster creation for node: ${INCUS_NODENAME^^}"

check_for_required_tools || {
	log "ERROR" "Required tools not found"
	exit 1
}

if [[ ${INCUS_NODENAME^^} == "${INCUS_CLUSTER_BOOTSTRAP_NODE^^}" ]]; then

	incus_bootstrap "$INCUS_NODENAME" "BOOTSTRAP" || {
		log "ERROR" "Failed to bootstrap cluster on node: ${INCUS_NODENAME^^}"
		exit 1
	}

else

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

log "INFO" "Incus cluster creation complete for node: ${INCUS_NODENAME^^}"
