#!/usr/bin/env bash

clear

set -euo pipefail

##################################################
# Variables
##################################################

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
	# TODO: Add back in the other hypervisors when testing is complete.
	"hypervisor-1"
	#"hypervisor-2"
	#"hypervisor-3"
	#"hypervisor-4"
)

##################################################
# Functions
##################################################

function print_header() {
	local HEADER=$1

	echo -e "\033[32m##################################################\033[0m"
	echo -e "\033[32m$HEADER\033[0m"
	echo -e "\033[32m##################################################\033[0m"

}

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

	return 0
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

	return 0
}

function copy_bootstrap_script() {
	local HYPERVISOR=$1

	msg "INFO" "Copying bootstrap-incus.sh to $HYPERVISOR"
	rsync -av ./scripts/bootstrap-incus.sh "${HYPERVISOR}.${DOMAIN}:/tmp/bootstrap-incus.sh" || {
		msg "ERROR" "Failed to copy bootstrap-incus.sh to $HYPERVISOR"
		exit 1
	}

	return 0
}

function reboot_server() {
	local HYPERVISOR=$1

	if [[ ${YOLO_MODE^^} == "FALSE" ]]; then
		read -rp "Reboot $HYPERVISOR? (y/n): " REPLY
	else
		REPLY="Y"
	fi

	if [[ ${REPLY^^} != "Y" ]]; then

		msg "INFO" "Skipping reboot for $HYPERVISOR"
		return 0

	else

		msg "INFO" "Rebooting $HYPERVISOR"
		run_ssh_command "$HYPERVISOR" "sudo -n systemctl reboot" "Failed to reboot $HYPERVISOR" || {
			msg "ERROR" "Failed to reboot $HYPERVISOR"
			return 1
		}

		return 0

	fi

}

function wait_for_server() {
	local HYPERVISOR=$1
	local MAX_ATTEMPTS=60
	local ATTEMPT=0
	local SLEEP_TIME=60
	local UPTIME_THRESHOLD=60 # 1 minute
	local UPTIME_SECONDS=0
	local SYSTEM_STATE="unknown"

	msg "INFO" "Waiting for $HYPERVISOR to come back online after reboot..."

	while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do

		# Reset UPTIME_SECONDS
		UPTIME_SECONDS=0

		# Increment attempt counter
		ATTEMPT=$((ATTEMPT + 1))

		msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking if $HYPERVISOR is online..."

		# First check if the host is reachable with ping
		if ping -c 1 -W 5 "${HYPERVISOR}.${DOMAIN}" &>/dev/null; then
			msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: Host is reachable, testing SSH..."

			# Then test SSH connection with more lenient settings
			if ssh -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 "${HYPERVISOR}.${DOMAIN}" "echo 'SSH connection OK!'" &>/dev/null; then
				msg "DEBUG" "SSH is available, checking uptime..."

				# Get uptime in seconds
				UPTIME_SECONDS=$(
					ssh \
						-o ConnectTimeout=15 \
						-o ServerAliveInterval=5 \
						-o ServerAliveCountMax=3 \
						"${HYPERVISOR}.${DOMAIN}" \
						"cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1" 2>/dev/null
				) || true

				msg "DEBUG" "${HYPERVISOR} uptime: $UPTIME_SECONDS seconds"

				if [[ $UPTIME_SECONDS -lt $UPTIME_THRESHOLD ]]; then
					msg "INFO" "$HYPERVISOR uptime is $UPTIME_SECONDS seconds, system has recently rebooted, waiting..."

					# Edge case: Wait an additional period of time to ensure all services are back online once SSH is working.
					sleep ${SLEEP_TIME} || echo "Failed to sleep for $SLEEP_TIME seconds"

				else

					# Check if the system is in shutdown state
					msg "DEBUG" "Checking if ${HYPERVISOR} is still rebooting..."

					SYSTEM_STATE=$(
						ssh \
							-o ConnectTimeout=15 \
							-o ServerAliveInterval=5 \
							-o ServerAliveCountMax=3 \
							"${HYPERVISOR}.${DOMAIN}" \
							"sudo -n systemctl is-system-running" 2>/dev/null
					) || true

					msg "DEBUG" "${HYPERVISOR} state: ${SYSTEM_STATE}"

					case "${SYSTEM_STATE^^}" in

					STOPPING) # Reboot in progress
						msg "INFO" "System is in stopping state (reboot in progress), waiting..."
						;;

					INITIALIZING) # System is still initializing after reboot
						msg "INFO" "System is initializing, waiting..."
						;;

					MAINTENANCE) # System is in maintenance
						msg "WARNING" "System is in maintenance, waiting..."
						;;

					DEGRADED) # System is degraded, but might have rebooted so OK to proceed.
						msg "WARNING" "System is degraded, skipping wait..."
						return 0
						;;

					RUNNING) # System is running, OK to proceed.
						msg "INFO" "System is running, skipping wait..."
						return 0
						;;

					*) # Unhandled state
						msg "WARNING" "System is in an unhandled state ($SYSTEM_STATE), retrying..."
						;;

					esac

				fi
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

	# Run nixos-rebuild
	run_nixos_rebuild "$HYPERVISOR"

	# Show system status
	show_system_status "$HYPERVISOR"

	# Copy and run bootstrap script
	copy_bootstrap_script "$HYPERVISOR"

	# Reboot the server
	if reboot_server "$HYPERVISOR"; then

		# Wait for server to come back online
		wait_for_server "$HYPERVISOR"

		# Now run the bootstrap script to capture tokens
		msg "INFO" "Running bootstrap-incus.sh on $HYPERVISOR to capture cluster tokens"
		run_ssh_command "$HYPERVISOR" "sudo -n bash /tmp/bootstrap-incus.sh" "Failed to run bootstrap-incus.sh on $HYPERVISOR"

	else

		msg "ERROR" "Failed to reboot $HYPERVISOR"
		exit 1

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

		Do not change the bootstrapped flag yet!

		##################################################
	EOF
	read -rp "Press enter to continue..."

	# Run nixos-rebuild
	run_nixos_rebuild "$HYPERVISOR"

	# Show system status
	show_system_status "$HYPERVISOR"

	# Copy and run bootstrap script
	copy_bootstrap_script "$HYPERVISOR"

	# Reboot the server
	if reboot_server "$HYPERVISOR"; then

		# Wait for server to come back online
		wait_for_server "$HYPERVISOR"

		# Now run the bootstrap script to capture tokens
		msg "INFO" "Running bootstrap-incus.sh on $HYPERVISOR in member mode"
		run_ssh_command "$HYPERVISOR" "sudo -n bash /tmp/bootstrap-incus.sh" "Failed to run bootstrap-incus.sh on $HYPERVISOR"

	else

		msg "ERROR" "Failed to reboot $HYPERVISOR"
		exit 1

	fi

	return 0
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

##################################################
# Pre-flight checks
##################################################

msg "INFO" "Starting pre-flight checks..."

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

# Before starting, ensure all servers are reachable.

msg "INFO" "Checking if all servers are reachable..."

for HYPERVISOR in "${HYPERVISORS[@]}"; do
	msg "INFO" "Checking if $HYPERVISOR is reachable (ping)..."

	ping -c 1 -W 5 "${HYPERVISOR}.${DOMAIN}" &>/dev/null || {
		msg "ERROR" "$HYPERVISOR is not reachable"
		exit 1
	}

	msg "INFO" "Checking if $HYPERVISOR is reachable (SSH)..."

	ssh -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 "${HYPERVISOR}.${DOMAIN}" "echo 'SSH connection OK!'" &>/dev/null || {
		msg "ERROR" "$HYPERVISOR is not reachable"
		exit 1
	}

done

msg "INFO" "Pre-flight checks completed successfully"

##################################################
# Main
##################################################

# Different message for destroy mode
if [[ ${INCUS_CLUSTER_DESTROY^^} == "TRUE" ]]; then
	msg "INFO" "Starting cluster destroy process..."
else
	msg "INFO" "Starting bootstrap process..."
fi

for HYPERVISOR in "${HYPERVISORS[@]}"; do
	msg "INFO" "Processing $HYPERVISOR"

	# DESTROY MODE
	if [[ ${INCUS_CLUSTER_DESTROY^^} == "TRUE" ]]; then

		print_header "MODE: Destroy"

		# Apply the `bootstrapped = false` flag on next boot.
		run_nixos_rebuild "$HYPERVISOR"

		# Blow away the cluster and all data.
		handle_cluster_destroy "$HYPERVISOR"

		# Reboot server without waiting for it to come back online
		reboot_server "$HYPERVISOR" || {
			msg "ERROR" "Failed to reboot $HYPERVISOR"
			exit 1
		}

	# BOOTSTRAP MODE
	elif [[ ${INCUS_CLUSTER_BOOTSTRAPPED^^} == "FALSE" ]]; then

		print_header "MODE: Bootstrap"

		# Handle cluster setup mode
		if [[ ${HYPERVISOR} == "${BOOTSTRAP_SERVER}" ]]; then
			setup_bootstrap_server "$HYPERVISOR"
		else
			setup_member_server "$HYPERVISOR"
		fi

	# UPGRADE MODE
	else

		print_header "MODE: Upgrade"

		run_nixos_rebuild "$HYPERVISOR"

		show_system_status "$HYPERVISOR"

		copy_bootstrap_script "$HYPERVISOR"

		if reboot_server "$HYPERVISOR"; then
			wait_for_server "$HYPERVISOR"
		else
			msg "ERROR" "Failed to reboot $HYPERVISOR"
			exit 1
		fi

	fi
done

# Show final notice for member servers but not in destroy mode
if [[ ${INCUS_CLUSTER_BOOTSTRAPPED^^} == "FALSE" && ${INCUS_CLUSTER_DESTROY^^} == "FALSE" ]]; then
	cat <<-EOF

		##################################################
		                    IMPORTANT
		##################################################

		Now that the initial setup has completed here are the next steps.

		- Verify that the member servers have joined the cluster

		    incus cluster list

		- Set the following environment variable in your shell:

		    INCUS_CLUSTER_BOOTSTRAPPED=true

		- Update the nix flake with the following for all servers (bootstrap and members):

		    bootstrapped = true

		- Re-run this script for a final time to complete the cluster setup.

		    ./scripts/bootstrap-hypervisors.sh

		##################################################
	EOF
fi

# Different message for destroy mode
if [[ ${INCUS_CLUSTER_DESTROY^^} == "TRUE" ]]; then
	msg "INFO" "Cluster destroy process completed successfully"
else
	msg "INFO" "Bootstrap process completed successfully"
fi
