#!/usr/bin/env bash

clear

set -euo pipefail

#########################
# Variables
#########################

# Set this to wipe the incus cluster on each node.
declare -r INCUS_CLUSTER_DESTROY=${INCUS_CLUSTER_DESTROY:-false}

# Set this when the cluster has been bootstrapped.
declare -r INCUS_CLUSTER_BOOTSTRAPPED=${INCUS_CLUSTER_BOOTSTRAPPED:-true}

# Don't ask for confirmation if enabled.
declare -r YOLO_MODE=${YOLO_MODE:-false}

DOMAIN="saltlabs.cloud"

# The bootstrap server.
BOOTSTRAP_SERVER="hypervisor-1"

# All hypervisors in the cluster.
HYPERVISORS=(
	"hypervisor-1"
	"hypervisor-2"
	"hypervisor-3"
	"hypervisor-4"
)

#########################
# Functions
#########################

function msg() {
	local LOG_LEVEL=$1
	local MESSAGE=$2
	local TIMESTAMP
	TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)

	case $LOG_LEVEL in
	DEBUG)
		echo -e "\033[34m[${TIMESTAMP}] [DEBUG] ${MESSAGE}\033[0m"
		;;
	INFO)
		echo -e "\033[32m[${TIMESTAMP}] [INFO] ${MESSAGE}\033[0m"
		;;
	WARNING)
		echo -e "\033[33m[${TIMESTAMP}] [WARNING] ${MESSAGE}\033[0m"
		;;
	ERROR)
		echo -e "\033[31m[${TIMESTAMP}] [ERROR] ${MESSAGE}\033[0m"
		;;
	*)
		echo -e "\033[37m[${TIMESTAMP}] [UNKNOWN] ${MESSAGE}\033[0m"
		;;
	esac
	return 0
}

function run_nixos_rebuild() {
	local HYPERVISOR=$1

	msg "INFO" "Running nixos-rebuild boot on $HYPERVISOR"

	nixos-rebuild boot \
		--use-remote-sudo \
		--accept-flake-config \
		--flake "path:.#${HYPERVISOR^^}" \
		--target-host "${HYPERVISOR}.${DOMAIN}" \
		--build-host "${HYPERVISOR}.${DOMAIN}" || {
		msg "ERROR" "Failed to upgrade $HYPERVISOR"
		exit 1
	}
}

function run_ssh_command() {
	local HYPERVISOR=$1
	local COMMAND=$2
	local ERROR_MSG=$3

	ssh -t -o RequestTTY=yes -o SendEnv=USER -o SendEnv=HOME -o SendEnv=LOGNAME "${HYPERVISOR}.${DOMAIN}" \
		"$COMMAND" || {
		msg "ERROR" "$ERROR_MSG"
		exit 1
	}
}

function show_system_status() {
	local HYPERVISOR=$1

	msg "INFO" "Showing zpool status on $HYPERVISOR"
	run_ssh_command "$HYPERVISOR" "sudo -n zpool status" "Failed to show zpool status on $HYPERVISOR"

	msg "INFO" "Showing failed systemd services on $HYPERVISOR"
	run_ssh_command "$HYPERVISOR" \
		"FAILED_UNITS=\$(sudo -n systemctl list-units --state=failed --plain --no-legend | awk '{print \$1}' | grep -v '^$');
		if [[ -n \"\$FAILED_UNITS\" ]]; then
			echo \"\$FAILED_UNITS\" | while read -r UNIT; do
				if [[ -n \"\$UNIT\" ]]; then
					echo \"Failed unit: \$UNIT\";
					sudo -n journalctl --no-pager --unit \"\$UNIT\" -n 25;
				fi
			done
		else
			echo \"No failed systemd services found\";
		fi" \
		"Failed to show failed systemd services on $HYPERVISOR"
}

function copy_bootstrap_script() {
	local HYPERVISOR=$1

	msg "INFO" "Copying bootstrap-incus.sh to $HYPERVISOR"
	rsync -av ./scripts/bootstrap-incus.sh "${HYPERVISOR}.${DOMAIN}:/tmp/bootstrap-incus.sh" || {
		msg "ERROR" "Failed to copy bootstrap-incus.sh to $HYPERVISOR"
		exit 1
	}
}

function reboot_server() {
	local HYPERVISOR=$1
	local SLEEP_TIME=15

	if [[ ${YOLO_MODE^^} == "FALSE" ]]; then
		read -rp "Reboot $HYPERVISOR? (y/n): " REPLY
	else
		REPLY="Y"
	fi

	if [[ ${REPLY^^} != "Y" ]]; then
		msg "INFO" "Skipping reboot for $HYPERVISOR"
		return 1
	else
		msg "INFO" "Rebooting $HYPERVISOR"
		run_ssh_command "$HYPERVISOR" "sudo -n systemctl reboot" "Failed to reboot $HYPERVISOR"
		sleep "$SLEEP_TIME" || echo "Failed to sleep for $SLEEP_TIME seconds"
		return 0
	fi
}

function wait_for_server() {
	local HYPERVISOR=$1
	local MAX_ATTEMPTS=30
	local ATTEMPT=0
	local SLEEP_TIME=15

	msg "INFO" "Waiting for $HYPERVISOR to come back online..."
	sleep "$SLEEP_TIME" || echo "Failed to sleep for $SLEEP_TIME seconds"

	while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
		ATTEMPT=$((ATTEMPT + 1))
		msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking if $HYPERVISOR is online..."

		# First check if the host is reachable with ping
		if ping -c 1 -W 5 "${HYPERVISOR}.${DOMAIN}" &>/dev/null; then
			msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: Host is reachable, testing SSH..."

			# Then test SSH connection with more lenient settings
			if ssh -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 "${HYPERVISOR}.${DOMAIN}" "echo 'SSH connection OK!'" &>/dev/null; then
				msg "INFO" "$HYPERVISOR is back online"
				return 0
			fi
		fi

		if [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; then
			msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: $HYPERVISOR not ready yet, waiting ${SLEEP_TIME}s..."
			sleep "$SLEEP_TIME" || echo "Failed to sleep for $SLEEP_TIME seconds"
		fi
	done

	msg "ERROR" "$HYPERVISOR did not come back online within expected time"
	exit 1
}

function setup_bootstrap_server() {
	local HYPERVISOR=$1

	msg "INFO" "Setting up bootstrap server: $HYPERVISOR"

	# Show notice to update flake
	cat <<-EOF
		##################################################
		                    IMPORTANT
		##################################################

		Update the nix flake now with the following for $HYPERVISOR:

		    bootstrapped = true

		Only this hypervisor needs to be updated for now.

		##################################################
	EOF
	read -rp "Press enter to continue..."

	# Run nixos-rebuild
	run_nixos_rebuild "$HYPERVISOR"

	# Show system status
	show_system_status "$HYPERVISOR"

	# Copy and run bootstrap script (but don't run it yet)
	copy_bootstrap_script "$HYPERVISOR"

	# Reboot the server
	if reboot_server "$HYPERVISOR"; then

		# Wait for server to come back online
		wait_for_server "$HYPERVISOR"

		# Now run the bootstrap script to capture tokens
		msg "INFO" "Running bootstrap-incus.sh on $HYPERVISOR to capture cluster tokens"
		run_ssh_command "$HYPERVISOR" "sudo -n bash /tmp/bootstrap-incus.sh" "Failed to run bootstrap-incus.sh on $HYPERVISOR"

	fi
}

function setup_member_server() {
	local HYPERVISOR=$1

	msg "INFO" "Setting up member server: $HYPERVISOR"

	# Show notice to update flake with cluster token
	cat <<-EOF
		##################################################
		                    IMPORTANT
		##################################################

		Update the nix flake now with the following for $HYPERVISOR:

		    clusterToken = <token>

		This token can be obtained from the bootstrap server output.

		Do not change the bootstrapped flag yet for this member server.

		##################################################
	EOF
	read -rp "Press enter to continue..."

	# Run nixos-rebuild
	run_nixos_rebuild "$HYPERVISOR"

	# Show system status
	show_system_status "$HYPERVISOR"

	# Copy and run bootstrap script
	copy_bootstrap_script "$HYPERVISOR"

	msg "INFO" "Running bootstrap-incus.sh on $HYPERVISOR in member mode"
	run_ssh_command "$HYPERVISOR" "sudo -n bash /tmp/bootstrap-incus.sh" "Failed to run bootstrap-incus.sh on $HYPERVISOR"
}

function handle_cluster_destroy() {
	local HYPERVISOR=$1

	msg "INFO" "Running bootstrap-incus.sh on $HYPERVISOR in destroy mode"

	# Show system status
	show_system_status "$HYPERVISOR"

	# Copy and run bootstrap script in destroy mode
	copy_bootstrap_script "$HYPERVISOR"

	run_ssh_command "$HYPERVISOR" "sudo -n bash /tmp/bootstrap-incus.sh --incus-destroy-cluster" "Failed to run bootstrap-incus.sh on $HYPERVISOR"
}

#########################
# Main
#########################

git add --all || {
	msg "ERROR" "Failed to stage git changes"
	exit 1
}

msg "INFO" "Checking Nix flake"

nix flake check \
	--accept-flake-config \
	--all-systems \
	--impure \
	--keep-going \
	--no-build \
	--refresh \
	--verbose || {
	msg "ERROR" "Failed to check Nix flake"
	exit 1
}

msg "DEBUG" "Debug information:"
msg "DEBUG" "HYPERVISORS: ${HYPERVISORS[*]}"
msg "DEBUG" "DOMAIN: $DOMAIN"
msg "DEBUG" "INCUS_CLUSTER_DESTROY: ${INCUS_CLUSTER_DESTROY^^}"
msg "DEBUG" "INCUS_CLUSTER_BOOTSTRAPPED: ${INCUS_CLUSTER_BOOTSTRAPPED^^}"

for HYPERVISOR in "${HYPERVISORS[@]}"; do
	msg "INFO" "Processing $HYPERVISOR"

	if [[ ${INCUS_CLUSTER_DESTROY^^} == "TRUE" ]]; then
		# Handle cluster destroy mode
		handle_cluster_destroy "$HYPERVISOR"

	elif [[ ${INCUS_CLUSTER_BOOTSTRAPPED^^} == "FALSE" ]]; then
		# Handle cluster setup mode
		if [[ ${HYPERVISOR} == "${BOOTSTRAP_SERVER}" ]]; then
			setup_bootstrap_server "$HYPERVISOR"
		else
			setup_member_server "$HYPERVISOR"
		fi
	else
		# Normal upgrade mode
		msg "INFO" "Upgrading $HYPERVISOR"
		run_nixos_rebuild "$HYPERVISOR"
		show_system_status "$HYPERVISOR"
		copy_bootstrap_script "$HYPERVISOR"

		# Reboot if needed
		reboot_server "$HYPERVISOR"

		# Wait for server to come back online
		wait_for_server "$HYPERVISOR"
	fi
done

# Show final notice for member servers
if [[ ${INCUS_CLUSTER_BOOTSTRAPPED^^} == "FALSE" ]]; then
	cat <<-EOF

		##################################################
		                    IMPORTANT
		##################################################

		Now that the initial setup has completed here are the next steps.

		- Verify that the member servers have joined the cluster

		    incus cluster list

		- Set the following environment variable in your shell:

		    INCUS_CLUSTER_BOOTSTRAPPED=true

		- Update the nix flake with the following for all member servers:

		    bootstrapped = true

		- Re-run this script for a final time.

		This completes the cluster setup process!

		##################################################
	EOF
fi

msg "INFO" "Bootstrap process completed successfully"
