#!/usr/bin/env bash

##################################################
# Disk Wipe Utility
#
# This script wipes all fixed disks (non-USB, non-ROM) detected on the system.
# It uses the 'wipefs' command to erase filesystem signatures, making disks appear unformatted.
#
# WARNING: This operation permanently erases all data on the targeted disks.
# There is no way to recover data after running this script.
#
# Ensure the system is running as root (sudo) for disk operations.
# Review the detected disks before confirming.
#
# Use at your own risk!
#
##################################################

set -euo pipefail

# ANSI color codes for logging
reset='\033[0m'
blue='\033[34m'   # DEBUG
green='\033[32m'  # INFO
yellow='\033[33m' # WARN
red='\033[31m'    # ERR

log() {
	local level=$1
	local msg=$2
	case $level in
	DEBUG) color=$blue ;;
	INFO) color=$green ;;
	WARN) color=$yellow ;;
	ERR) color=$red ;;
	*) color=$reset ;;
	esac
	echo -e "${color}[$level]${reset} $msg"
}

##################################################
# Confirmation
##################################################

get_confirmation() {
	log WARN "This will wipe every fixed disk it finds. Are you sure about this? [y/N]"
	read -rp "Response: " response
	[[ ${response:-} == [yY] ]]
}

##################################################
# Disk Detection
##################################################

get_disks() {
	disks_to_wipe=()
	ignored_disks=()
	while read -r name type tran; do
		if [ "$type" = "disk" ] && [ "$tran" != "usb" ]; then
			disks_to_wipe+=("/dev/$name")
		elif [ "$type" = "rom" ] || [ "$tran" = "usb" ]; then
			ignored_disks+=("/dev/$name")
		fi
	done < <(lsblk -dno NAME,TYPE,TRAN)
}

##################################################
# Wipe Operations
##################################################

wipe_disk() {
	local disk=$1
	if wipefs -af "$disk" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

wipe_all_disks() {
	wiped=()
	failed=()
	for disk in "${disks_to_wipe[@]}"; do
		log INFO "Wiping $disk"
		if wipe_disk "$disk"; then
			wiped+=("$disk")
			log INFO "Successfully wiped $disk"
		else
			failed+=("$disk")
			log ERR "Failed to wipe $disk"
		fi
	done
}

##################################################
# Summary
##################################################

print_summary() {
	if [ ${#disks_to_wipe[@]} -eq 0 ]; then
		log INFO "No disks to wipe found."
		return
	fi

	echo -e "\n${green}=========================================${reset}"
	echo -e "${green}         OPERATION SUMMARY${reset}"
	echo -e "${green}=========================================${reset}"

	echo -e "${green}Wiped disks (${#wiped[@]}):${reset}"
	if [ ${#wiped[@]} -gt 0 ]; then
		for d in "${wiped[@]}"; do
			echo -e "${green}  ✓ $d${reset}"
		done
	else
		echo -e "${yellow}  None${reset}"
	fi

	echo

	echo -e "${red}Failed wipes (${#failed[@]}):${reset}"
	if [ ${#failed[@]} -gt 0 ]; then
		for d in "${failed[@]}"; do
			echo -e "${red}  ✗ $d${reset}"
		done
	else
		echo -e "${green}  None${reset}"
	fi

	echo

	echo -e "${blue}Ignored disks (${#ignored_disks[@]}):${reset}"
	if [ ${#ignored_disks[@]} -gt 0 ]; then
		for d in "${ignored_disks[@]}"; do
			echo -e "${blue}  - $d${reset}"
		done
	else
		echo -e "${yellow}  None${reset}"
	fi

	echo -e "${green}=========================================${reset}"
}

##################################################
# Main
##################################################

main() {
	if [ "$EUID" -ne 0 ]; then
		log ERR "This script must be run as root (sudo)."
		exit 1
	fi
	log INFO "Starting disk wipe script"
	if ! get_confirmation; then
		log INFO "Aborted by user."
		exit 0
	fi
	get_disks
	log INFO "Detected ${#disks_to_wipe[@]} disk(s) to wipe: ${disks_to_wipe[*]:-None}"
	log INFO "Detected ${#ignored_disks[@]} ignored disk(s): ${ignored_disks[*]:-None}"
	wipe_all_disks
	print_summary
}

main "$@"
