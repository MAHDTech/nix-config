#!/usr/bin/env bash

clear
set -euo pipefail

################################################################################
# Variables
################################################################################

SERVER=${1:-}
SYSTEMD_UNIT=${2:-}
ACTION=${3:-"journal"}
RECONNECT_INTERVAL=${4:-15}

################################################################################
# Functions
################################################################################

function help() {
	cat <<-EOF
		Usage: $0 <server> <systemd-unit> <action> <reconnect-interval>

		Server:
		    The remote server to connect to.

		Unit:
		    The systemd unit

		Actions:
		    journal - Show journal for systemd unit
		    restart - Restart systemd unit

		Reconnect interval:
		    The interval in seconds to reconnect to the server.

		Examples:
		    $0 server1 systemd-unit.service journal 15
		    $0 server1 systemd-unit.service restart 15
	EOF
}

function msg() {
	local LOG_LEVEL=$1
	local MESSAGE=$2

	case $LOG_LEVEL in
	DEBUG)
		echo -e "\033[34m[DEBUG] $MESSAGE\033[0m" # Blue
		;;
	INFO)
		echo -e "\033[32m[INFO] $MESSAGE\033[0m" # Green
		;;
	WARNING)
		echo -e "\033[33m[WARNING] $MESSAGE\033[0m" # Yellow
		;;
	ERROR)
		echo -e "\033[31m[ERROR] $MESSAGE\033[0m" # Red
		;;
	*)
		echo -e "\033[35m[UNKNOWN] $MESSAGE\033[0m" # Purple
		;;
	esac
}

################################################################################
# Main
################################################################################

# Make sure the server is provided.
if [ "${SERVER:-EMPTY}" = "EMPTY" ]; then
	msg ERROR "Please provide server as parameter 1"
	help
	exit 1
fi

# Make sure the systemd unit is provided.
if [ "${SYSTEMD_UNIT:-EMPTY}" = "EMPTY" ]; then
	msg ERROR "Please provide systemd unit as parameter 2"
	help
	exit 1
fi

msg INFO "Connecting to server ${SERVER} to perform action ${ACTION} on ${SYSTEMD_UNIT}..."

case $ACTION in

journal)

	while true; do

		ssh -t -o RequestTTY=yes -o SendEnv=USER -o SendEnv=HOME -o SendEnv=LOGNAME "${SERVER}" \
			"sudo -n journalctl --no-pager --follow --unit '${SYSTEMD_UNIT}' -n 25" || {
			msg INFO "The ssh session has ended."
		} || {
			msg WARNING "Failed to connect or show journal for ${SYSTEMD_UNIT} on ${SERVER}. Retrying in 15 seconds..."
		}

		clear
		echo -e "\033[33m[WARNING] ################################################################################\033[0m"
		echo -e "\033[33m[WARNING] Re-connecting to server in ${RECONNECT_INTERVAL} seconds...\033[0m"
		echo -e "\033[33m[WARNING] ################################################################################\033[0m"
		sleep "${RECONNECT_INTERVAL}"

	done

	;;

restart)

	ssh -t -o RequestTTY=yes -o SendEnv=USER -o SendEnv=HOME -o SendEnv=LOGNAME "${SERVER}" \
		"sudo -n systemctl restart '${SYSTEMD_UNIT}'" || {
		msg INFO "Failed to restart ${SYSTEMD_UNIT} on ${SERVER}"
	} || {
		msg INFO "The ssh session has ended."
	}
	;;

*)
	msg ERROR "Invalid action: ${ACTION}"
	help
	exit 1
	;;

esac

msg INFO "Done."
