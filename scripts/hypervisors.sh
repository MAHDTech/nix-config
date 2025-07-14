#!/usr/bin/env bash

clear

set -euo pipefail

DOMAIN="saltlabs.cloud"

HYPERVISORS=(
	"hypervisor-1"
	"hypervisor-2"
	"hypervisor-3"
	"hypervisor-4"
)

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

git add --all || {
	msg "ERROR" "Failed to stage git changes"
	exit 1
}

for HYPERVISOR in "${HYPERVISORS[@]}"; do

	msg "INFO" "Testing sudo access on $HYPERVISOR"

	ssh -t "${HYPERVISOR}.${DOMAIN}" "id && groups && sudo -l" || {
		msg "ERROR" "Failed to test sudo access on $HYPERVISOR"
		exit 1
	}

	msg "INFO" "Upgrading $HYPERVISOR"

	nixos-rebuild boot \
		--use-remote-sudo \
		--accept-flake-config \
		--flake "path:.#${HYPERVISOR^^}" \
		--target-host "${HYPERVISOR}.${DOMAIN}" \
		--build-host "${HYPERVISOR}.${DOMAIN}" || {
		msg "ERROR" "Failed to upgrade $HYPERVISOR"
		exit 1
	}

	msg "INFO" "Restarting nixos-upgrade on $HYPERVISOR"

	# Use SSH with proper environment preservation
	ssh -t -o RequestTTY=yes -o SendEnv=USER -o SendEnv=HOME -o SendEnv=LOGNAME "${HYPERVISOR}.${DOMAIN}" \
		"sudo -n systemctl restart nixos-upgrade" || {
		msg "ERROR" "Failed to restart nixos-upgrade on $HYPERVISOR"
		exit 1
	}

	msg "INFO" "Rebooting $HYPERVISOR"

	# Use SSH with proper environment preservation
	ssh -t -o RequestTTY=yes -o SendEnv=USER -o SendEnv=HOME -o SendEnv=LOGNAME "${HYPERVISOR}.${DOMAIN}" \
		"sudo -n systemctl reboot" || {
		msg "ERROR" "Failed to reboot $HYPERVISOR"
		exit 1
	}

done
