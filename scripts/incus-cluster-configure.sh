#!/usr/bin/env bash

set -euo pipefail

# Name: incus-cluster-configure.sh
# Description: Configure Incus cluster settings.

##################################################
# Variables
##################################################

declare -r REQUIRED_TOOLS=(
	"incus"
	"jq"
)

declare -r INCUS_PROJECTS=(
	"default"
)

declare -A INCUS_OCI_REGISTRIES=(
	["docker.io"]="https://index.docker.io"
	["ghcr.io"]="https://ghcr.io"
	["quay.io"]="https://quay.io"
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

function check_for_required_permissions() {

	# Make sure the user is in the 'incus-admin' group.
	if ! groups | grep -q "incus-admin"; then
		log "ERROR" "User ${USER} is not in the 'incus-admin' group"
		return 1
	fi

	return 0
}

function configure_oci_registries() {
	local INCUS_REMOTES

	# Get the current list of registries in JSON format.
	INCUS_REMOTES=$(incus remote list --format json)

	# For each project, add the OCI registries.
	for PROJECT in "${INCUS_PROJECTS[@]}"; do
		log "INFO" "Adding OCI registries to project ${PROJECT}"

		incus project switch "${PROJECT}" || {
			log "WARNING" "Failed to switch to project ${PROJECT}, does it exist? Skipping."
			continue
		}

		# Add or update the OCI registries.
		for REGISTRY in "${!INCUS_OCI_REGISTRIES[@]}"; do

			# Split the registry name and URL.
			REGISTRY_NAME="${REGISTRY}"
			REGISTRY_URL="${INCUS_OCI_REGISTRIES[${REGISTRY}]}"

			# Check if the registry exists and remove it if it does.
			EXISTING_REMOTE=$(echo "${INCUS_REMOTES}" | jq -e --arg name "${REGISTRY_NAME}" '.[$name] // empty')

			if [ -n "${EXISTING_REMOTE}" ]; then

				log "INFO" "Removing existing remote ${REGISTRY_NAME} from project ${PROJECT}"
				incus remote remove \
					"${REGISTRY_NAME}" ||
					{
						log "ERROR" "Failed to delete remote ${REGISTRY_NAME} from project ${PROJECT}"
						return 1
					}

			fi

			log "INFO" "Adding new remote ${REGISTRY_NAME} with URL ${REGISTRY_URL} to project ${PROJECT}"
			incus remote add \
				"${REGISTRY_NAME}" \
				"${REGISTRY_URL}" \
				--protocol=oci \
				--public \
				--force-local ||
				{
					log "ERROR" "Failed to add remote ${REGISTRY_NAME} with URL ${REGISTRY_URL} to project ${PROJECT}"
					return 1
				}

		done

	done

	return 0
}

##################################################
# Main
##################################################

log "INFO" "Starting incus cluster configuration"

check_for_required_tools || {
	log "ERROR" "Required tools not found"
	exit 1
}

check_for_required_permissions || {
	log "ERROR" "Insufficient permissions to configure incus cluster"
	exit 1
}

# Add OCI container registries.
configure_oci_registries || {
	log "ERROR" "Failed to configure OCI registries"
	exit 1
}

log "INFO" "Incus cluster configuration complete"

exit 0
