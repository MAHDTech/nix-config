#!/usr/bin/env bash

clear

set -euo pipefail

##################################################
# Variables
##################################################

declare -r DOMAIN="saltlabs.cloud"

# The bootstrap server.
declare -r BOOTSTRAP_SERVER="hypervisor-1"

# All hypervisors in the cluster.
declare -r HYPERVISORS=(
	"hypervisor-1"
	"hypervisor-2"
	"hypervisor-3"
	"hypervisor-4"
)

declare -r REQUIRED_NIXPKGS=(
	"incus"
	"jq"
	"nftables"
	"openvswitch"
	"ovn"
	"zfs"
)

##################################################
# Functions
##################################################

function print_usage() {
	cat <<-EOF
		Usage: $0 [--create|--join|--destroy|--apply|--health|--test]

		Options:

		    --destroy   Destroy an incus cluster
		    --create    Create a new incus cluster
		    --join      Join an existing incus cluster
		    --apply     Apply changes to an incus cluster
		    --configure Configure an incus cluster
		    --health    Check health of all services
		    --test      Run a test script on all servers

		Additional options:

		    --yolo      Skip all interactive prompts
		    --force-reboot  Force immediate reboot after applying changes

		If no options are provided, the script will default to --apply.
	EOF
}

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
	local ACTION=${2:-boot}

	msg "INFO" "Running nixos-rebuild ${ACTION} on ${HYPERVISOR}"

	nixos-rebuild "${ACTION}" \
		--use-remote-sudo \
		--accept-flake-config \
		--flake "path:.#${HYPERVISOR^^}" \
		--target-host "${HYPERVISOR}.${DOMAIN}" \
		--build-host "${HYPERVISOR}.${DOMAIN}" || {
		msg "ERROR" "Failed to apply changes to ${HYPERVISOR}"
		return 1
	}
}

function run_ssh_command() {
	local HYPERVISOR=$1
	local COMMAND=$2

	ssh -t -o RequestTTY=yes -o SendEnv=USER -o SendEnv=HOME -o SendEnv=LOGNAME "${HYPERVISOR}.${DOMAIN}" "$COMMAND" || {
		return 1
	}

	return 0
}

function show_system_status() {
	local HYPERVISOR=$1

	msg "INFO" "Upgrading zpool on ${HYPERVISOR}"
	run_ssh_command "${HYPERVISOR}" "sudo -n zpool upgrade zpool" || {
		msg "WARNING" "Failed to upgrade zpool on ${HYPERVISOR}"
	}

	msg "INFO" "Showing zpool status on ${HYPERVISOR}"
	run_ssh_command "${HYPERVISOR}" "sudo -n zpool status" || {
		msg "ERROR" "Failed to show zpool status on ${HYPERVISOR}"
		return 1
	}

	msg "INFO" "Showing failed systemd services on ${HYPERVISOR}"
	run_ssh_command "${HYPERVISOR}" \
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
		fi" || {
		msg "ERROR" "Failed to show failed systemd services on ${HYPERVISOR}"
		return 1
	}

	return 0
}

function copy_script() {
	local SCRIPT=$1
	local HYPERVISOR=$2

	msg "INFO" "Copying ${SCRIPT} to ${HYPERVISOR}"
	rsync -av "./scripts/${SCRIPT}" "${HYPERVISOR}.${DOMAIN}:/tmp/${SCRIPT}" || {
		msg "ERROR" "Failed to copy ${SCRIPT} to ${HYPERVISOR}"
		return 1
	}

	return 0
}

function reboot_server() {
	local HYPERVISOR=$1

	if [[ ${YOLO_MODE^^} == "FALSE" ]]; then
		read -rp "Reboot ${HYPERVISOR}? (y/n): " REPLY
	else
		REPLY="Y"
	fi

	if [[ ${REPLY^^} != "Y" ]]; then

		msg "INFO" "Skipping reboot for ${HYPERVISOR}"
		return 0

	else

		msg "INFO" "Starting reboot of ${HYPERVISOR}..."
		run_ssh_command "${HYPERVISOR}" "sudo -n systemctl reboot" || {
			msg "ERROR" "Failed to reboot ${HYPERVISOR}"
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
	local UPTIME_THRESHOLD=180 # 3 minutes
	local UPTIME_SECONDS=0
	local SYSTEM_STATE="unknown"

	msg "INFO" "Waiting for ${HYPERVISOR} to come back online after reboot..."

	while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do

		# Reset UPTIME_SECONDS
		UPTIME_SECONDS=0

		# Increment attempt counter
		ATTEMPT=$((ATTEMPT + 1))

		msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking if ${HYPERVISOR} is online..."

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
					msg "INFO" "${HYPERVISOR} uptime is $UPTIME_SECONDS seconds, system has recently rebooted, waiting..."

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
			msg "DEBUG" "Attempt $ATTEMPT/$MAX_ATTEMPTS: ${HYPERVISOR} not ready yet, waiting ${SLEEP_TIME}s..."
			sleep "$SLEEP_TIME" || echo "Failed to sleep for $SLEEP_TIME seconds"
		fi
	done

	msg "ERROR" "${HYPERVISOR} did not come back online within expected time"
	return 1
}

function apply_changes() {
	local HYPERVISOR=$1
	local REBOOT=${2:-}

	# Default to true if not set.
	REBOOT=${REBOOT:-true}

	msg "INFO" "Applying changes to ${HYPERVISOR}"

	run_nixos_rebuild "${HYPERVISOR}" boot || {
		msg "ERROR" "Failed to apply changes to ${HYPERVISOR}"
		return 1
	}

	show_system_status "${HYPERVISOR}" || {
		msg "ERROR" "Failed to show system status on ${HYPERVISOR}"
		return 1
	}

	if [[ ${REBOOT^^} == "TRUE" ]]; then
		if reboot_server "${HYPERVISOR}"; then
			if [[ ${FORCE_REBOOT^^} == "FALSE" ]]; then
				wait_for_server "${HYPERVISOR}"
			else
				msg "INFO" "Force reboot enabled, skipping wait for ${HYPERVISOR}"
			fi
		else
			msg "ERROR" "Failed to reboot ${HYPERVISOR}"
			return 1
		fi
		msg "INFO" "Changes applied and rebooted ${HYPERVISOR}"
	else
		msg "INFO" "Changes applied to ${HYPERVISOR} without reboot"
	fi

	return 0

}

function setup_server() {
	local HYPERVISOR=$1
	local SERVER_TYPE

	if [[ ${HYPERVISOR^^} == "${BOOTSTRAP_SERVER^^}" ]]; then
		SERVER_TYPE="bootstrap"
	else
		SERVER_TYPE="member"
	fi

	# Apply Nix changes on reboot and trigger a reboot now.
	apply_changes "${HYPERVISOR}" true || {
		msg "ERROR" "Failed to apply changes to ${HYPERVISOR}"
		return 1
	}

	# Copy across the incus cluster creation script.
	copy_script "incus-cluster-create.sh" "${HYPERVISOR}" || {
		msg "ERROR" "Failed to copy incus-cluster-create.sh to ${HYPERVISOR}"
		return 1
	}

	# Run the cluster creation script inside a nix-shell with the required tools.
	msg "INFO" "Running incus-cluster-create.sh on ${HYPERVISOR} in ${SERVER_TYPE} mode"
	run_ssh_command "${HYPERVISOR}" \
		"sudo -n nix-shell -p ${REQUIRED_NIXPKGS[*]} --command 'bash /tmp/incus-cluster-create.sh'" || {
		msg "ERROR" "Failed to run incus-cluster-create.sh on ${HYPERVISOR}"
		return 1
	}

	return 0
}

function destroy_server() {
	local HYPERVISOR=$1

	# Copy across the incus cluster destruction script.
	copy_script "incus-cluster-destroy.sh" "${HYPERVISOR}" || {
		msg "ERROR" "Failed to copy incus-cluster-destroy.sh to ${HYPERVISOR}"
		return 1
	}

	# Run the bootstrap script inside a nix-shell with the required tools.
	msg "INFO" "Running incus-cluster-destroy.sh on ${HYPERVISOR} in destroy mode"
	run_ssh_command "${HYPERVISOR}" \
		"sudo -n nix-shell -p ${REQUIRED_NIXPKGS[*]} --command 'bash /tmp/incus-cluster-destroy.sh'" || {
		msg "ERROR" "Failed to run incus-cluster-destroy.sh on ${HYPERVISOR}"
		return 1
	}

	# Apply Nix changes on reboot and trigger a reboot now.
	apply_changes "${HYPERVISOR}" true || {
		msg "ERROR" "Failed to apply changes to ${HYPERVISOR}"
		return 1
	}

	return 0
}

function configure_server() {
	local HYPERVISOR=$1

	# Copy across the incus cluster configuration script.
	copy_script "incus-cluster-configure.sh" "${HYPERVISOR}" || {
		msg "ERROR" "Failed to copy incus-cluster-configure.sh to ${HYPERVISOR}"
		return 1
	}

	# Run the cluster configuration script inside a nix-shell with the required tools.
	# This script must NOT be run using sudo, and the user must be in the 'incus-admin' group.
	msg "INFO" "Running incus-cluster-configure.sh on ${HYPERVISOR} as user ${USER}"
	run_ssh_command "${HYPERVISOR}" \
		"nix-shell -p ${REQUIRED_NIXPKGS[*]} --command 'bash /tmp/incus-cluster-configure.sh'" || {
		msg "ERROR" "Failed to run incus-cluster-configure.sh on ${HYPERVISOR}"
		return 1
	}

	return 0
}

function health_check_server() {
	local HYPERVISOR=$1

	# Copy across the incus cluster health check script.
	copy_script "incus-cluster-health.sh" "${HYPERVISOR}" || {
		msg "ERROR" "Failed to copy incus-cluster-health.sh to ${HYPERVISOR}"
		return 1
	}

	# Run the health check script inside a nix-shell with the required tools.
	msg "INFO" "Running incus-cluster-health.sh on ${HYPERVISOR}"
	run_ssh_command "${HYPERVISOR}" \
		"sudo -n nix-shell -p ${REQUIRED_NIXPKGS[*]} --command 'bash /tmp/incus-cluster-health.sh'" || {
		msg "ERROR" "Failed to run incus-cluster-health.sh on ${HYPERVISOR}"
		return 1
	}

	return 0
}

function run_test_script() {
	local HYPERVISOR=$1
	local PARENT_DATASET="zpool/var/lib/storage-pools"
	local TEST_COUNT=10

	# Copy across the incus cluster test script.
	copy_script "incus-cluster-test.sh" "${HYPERVISOR}" || {
		msg "ERROR" "Failed to copy incus-cluster-test.sh to ${HYPERVISOR}"
		return 1
	}

	# Run the test script inside a nix-shell with the required tools.
	msg "INFO" "Running incus-cluster-test.sh on ${HYPERVISOR}"
	run_ssh_command "${HYPERVISOR}" \
		"sudo -n nix-shell -p ${REQUIRED_NIXPKGS[*]} \
		--command 'bash /tmp/incus-cluster-test.sh --dataset ${PARENT_DATASET} --count ${TEST_COUNT}'" || {
		msg "ERROR" "Failed to run incus-cluster-test.sh on ${HYPERVISOR}"
		return 1
	}

	return 0
}

##################################################
# Argument Parsing
##################################################

# Use getopt to parse arguments
OPTS=$(getopt -o "cjdahyofet" --long "create,join,destroy,apply,help,yolo,configure,force-reboot,health,test" -n "$0" -- "$@")
# shellcheck disable=SC2181
if [ $? != 0 ]; then
	print_usage
	exit 1
fi

eval set -- "$OPTS"

# Initialize flags
declare INCUS_CLUSTER_CREATE=false
declare INCUS_CLUSTER_JOIN=false
declare INCUS_CLUSTER_DESTROY=false
declare INCUS_CLUSTER_APPLY=false
declare INCUS_CLUSTER_CONFIGURE=false
declare INCUS_CLUSTER_HEALTH=false
declare INCUS_CLUSTER_TEST=false
declare YOLO_MODE=false
declare FORCE_REBOOT=false
declare MODE=""

while true; do

	case "$1" in
	-c | --create)
		INCUS_CLUSTER_CREATE=true
		MODE="create"
		shift
		;;
	-j | --join)
		INCUS_CLUSTER_JOIN=true
		MODE="join"
		shift
		;;
	-d | --destroy)
		INCUS_CLUSTER_DESTROY=true
		MODE="destroy"
		shift
		;;
	-a | --apply)
		INCUS_CLUSTER_APPLY=true
		MODE="apply"
		shift
		;;
	-y | --yolo)
		YOLO_MODE=true
		shift
		;;
	-o | --configure)
		INCUS_CLUSTER_CONFIGURE=true
		MODE="configure"
		shift
		;;
	-e | --health)
		INCUS_CLUSTER_HEALTH=true
		MODE="health"
		shift
		;;
	-h | --help)
		print_usage
		exit 0
		;;
	-f | --force-reboot)
		FORCE_REBOOT=true
		shift
		;;
	-t | --test)
		INCUS_CLUSTER_TEST=true
		MODE="test"
		shift
		;;
	--)
		shift
		break
		;;
	*)
		msg "ERROR" "Invalid argument: $1"
		print_usage
		exit 1
		;;
	esac
done

# Ensure exactly one mode is selected (mutual exclusivity)
MODE_COUNT=0
[[ $INCUS_CLUSTER_CREATE == true ]] && ((MODE_COUNT = MODE_COUNT + 1))
[[ $INCUS_CLUSTER_JOIN == true ]] && ((MODE_COUNT = MODE_COUNT + 1))
[[ $INCUS_CLUSTER_DESTROY == true ]] && ((MODE_COUNT = MODE_COUNT + 1))
[[ $INCUS_CLUSTER_APPLY == true ]] && ((MODE_COUNT = MODE_COUNT + 1))
[[ $INCUS_CLUSTER_CONFIGURE == true ]] && ((MODE_COUNT = MODE_COUNT + 1))
[[ $INCUS_CLUSTER_HEALTH == true ]] && ((MODE_COUNT = MODE_COUNT + 1))
[[ $INCUS_CLUSTER_TEST == true ]] && ((MODE_COUNT = MODE_COUNT + 1))

if [[ ${FORCE_REBOOT^^} == "TRUE" ]]; then
	msg "INFO" "Force reboot enabled"
else
	msg "INFO" "Force reboot disabled"
fi

if [ $MODE_COUNT -gt 1 ]; then
	msg "ERROR" "Only one mode can be specified (--create, --join, --destroy, --apply, --configure, --health, or --test)."
	print_usage
	exit 1
elif [ $MODE_COUNT -eq 0 ]; then
	# Default to apply if no mode specified
	INCUS_CLUSTER_APPLY=true
	MODE="apply"
	msg "INFO" "No mode specified; defaulting to --apply."
fi

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

msg "INFO" "Checking if all servers are reachable..."

for HYPERVISOR in "${HYPERVISORS[@]}"; do
	msg "INFO" "Checking if ${HYPERVISOR} is reachable (ping)..."

	ping -c 1 -W 5 "${HYPERVISOR}.${DOMAIN}" &>/dev/null || {
		msg "ERROR" "${HYPERVISOR} is not reachable"
		exit 1
	}

	msg "INFO" "Checking if ${HYPERVISOR} is reachable (SSH)..."

	ssh -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 "${HYPERVISOR}.${DOMAIN}" "echo 'SSH connection OK!'" &>/dev/null || {
		msg "ERROR" "${HYPERVISOR} is not reachable"
		exit 1
	}

done

msg "INFO" "Pre-flight checks completed successfully"

##################################################
# Main
##################################################

msg "INFO" "Starting cluster ${MODE} process..."

for HYPERVISOR in "${HYPERVISORS[@]}"; do

	print_header "Starting ${MODE} process for ${HYPERVISOR}"

	case "${MODE^^}" in

	# Destroy incus on all servers.
	"DESTROY")

		destroy_server "${HYPERVISOR}" || {
			msg "ERROR" "Failed to destroy server ${HYPERVISOR}"
			exit 1
		}

		;;

	# Create the incus cluster on the bootstrap server only.
	"CREATE")

		# If it's the bootstrap server, create the cluster.
		if [[ ${HYPERVISOR^^} == "${BOOTSTRAP_SERVER^^}" ]]; then
			msg "INFO" "Bootstrapping incus cluster on server ${HYPERVISOR}"
			setup_server "${HYPERVISOR}" || {
				msg "ERROR" "Failed to setup server ${HYPERVISOR}"
				exit 1
			}
		fi

		;;

	# Join the incus cluster from member servers only.
	"JOIN")

		# If it's the bootstrap server, don't attempt to join it.
		if [[ ${HYPERVISOR^^} == "${BOOTSTRAP_SERVER^^}" ]]; then
			msg "INFO" "Skipping join for bootstrap server ${HYPERVISOR}"
		else
			# Apply changes to the server and reboot now.
			apply_changes "${HYPERVISOR}" true || {
				msg "ERROR" "Failed to join server ${HYPERVISOR}"
				exit 1
			}
		fi

		;;

	# Apply changes to all servers.
	"APPLY")

		apply_changes "${HYPERVISOR}" true || {
			msg "ERROR" "Failed to apply changes to server ${HYPERVISOR}"
			exit 1
		}

		;;

	# Configure the incus cluster on all servers.
	"CONFIGURE")

		# If it's the bootstrap server, run the configuration script on it.
		if [[ ${HYPERVISOR^^} == "${BOOTSTRAP_SERVER^^}" ]]; then
			configure_server "${HYPERVISOR}" || {
				msg "ERROR" "Failed to setup server ${HYPERVISOR}"
				exit 1
			}
		else
			msg "INFO" "Skipping cluster creation for non-bootstrap server ${HYPERVISOR}"
		fi

		;;

	# Check health of all services on all servers.
	"HEALTH")

		health_check_server "${HYPERVISOR}" || {
			msg "ERROR" "Health check failed for server ${HYPERVISOR}"
			exit 1
		}

		;;

	# Run a test script on all servers.
	"TEST")
		run_test_script "${HYPERVISOR}" || {
			msg "ERROR" "Test script failed for server ${HYPERVISOR}"
			exit 1
		}
		;;

	*)

		msg "ERROR" "Invalid mode: ${MODE^^}"
		exit 1

		;;

	esac

done

msg "INFO" "Cluster ${MODE} process completed successfully"
