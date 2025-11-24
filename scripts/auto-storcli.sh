#!/usr/bin/env bash

#########################
# Name: auto-storcli.sh
# Description: Flashes firmware to Broadcom SAS controllers so you don't need to remember those pesky CLI commands.
# Usage: ./auto-storcli.sh [--log-level LEVEL] [--log-file-level LEVEL]
#########################

clear
set -euo pipefail

#########################
# Variables
#########################

# Download bundle URL
DOWNLOAD_BUNDLE_URL="http://bootycall.saltlabs.cloud/downloads/Firmware_9500-8i.tar.gz"

# AMD64 File Locations
# shellcheck disable=SC2034
AMD64_FILE_STORCLI="AMD64/storcli_007.3503.0000.0000_all.deb"
# shellcheck disable=SC2034
AMD64_FILE_FIRMWARE="AMD64/Firmware/HBA_9500-8i_SAS_SATA_Profile.bin"
# shellcheck disable=SC2034
AMD64_FILE_BIOS=""
# shellcheck disable=SC2034
AMD64_FILE_PSOC="AMD64/Firmware/pblp_catalog.signed.rom"

# ARM64 File Locations
# shellcheck disable=SC2034
ARM64_FILE_STORCLI="ARM64/storcli64_007.3503.0000.0000_arm64.deb"
# shellcheck disable=SC2034
ARM64_FILE_FIRMWARE="ARM64/Firmware/HBA_9500-8i_SAS_SATA_Profile.bin"
# shellcheck disable=SC2034
ARM64_FILE_BIOS="ARM64/Firmware/IT_HBA_ARM_UEFI_PKG_E6.rom"
# shellcheck disable=SC2034
ARM64_FILE_PSOC="ARM64/Firmware/pblp_catalog.signed.rom"

# Default settings
LOG_LEVEL_SCREEN="warn"
LOG_LEVEL_FILE="debug"

#########################
# Constants
#########################

declare -r SCRIPT_NAME="${0##*/}"
declare -r SCRIPT_BASE="${SCRIPT_NAME%.*}"
declare -r LOG_FILE="${PWD}/${SCRIPT_BASE}.log"

# Temporary working directory for downloads and extraction
WORK_DIR=$(mktemp -d) || {
	echo "Failed to create temp dir" >&2
	exit 1
}

# Colors for on-screen logging
declare -r RED='\033[0;31m'
declare -r YELLOW='\033[0;33m'
declare -r GREEN='\033[0;32m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m' # No Color

#########################
# Functions
#########################

# Function to cleanup temporary working directory on exit.
function cleanup() {
	if [[ -n ${WORK_DIR:-} && -d $WORK_DIR ]]; then
		read -rp "Press any key to cleanup temporary working directory or Ctrl+C to cancel..." </dev/tty
		log info "Cleaning up temporary working directory..."
		rm -rf "$WORK_DIR" || {
			log warn "Failed to remove temporary directory: $WORK_DIR, manual cleanup required"
		}
	else
		log warn "Temporary working directory not found or not a directory"
	fi
}

# Function to parse command-line arguments
function parse_args() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		--log-level)
			LOG_LEVEL_SCREEN="$2"
			shift 2
			;;
		--log-file-level)
			LOG_LEVEL_FILE="$2"
			shift 2
			;;
		*)
			log error "Unknown option: $1"
			return 1
			;;
		esac
	done
}

# Function to get numeric value for log level
function get_level_num() {
	case $1 in
	debug) echo 0 ;;
	info) echo 1 ;;
	warn) echo 2 ;;
	error) echo 3 ;;
	*) echo 3 ;; # Default to error
	esac
}

# Logging functions
log_to_file() {
	local level=$1
	local msg=$2
	local file_num
	file_num=$(get_level_num "$LOG_LEVEL_FILE")
	local msg_num
	msg_num=$(get_level_num "$level")
	if [ "$msg_num" -ge "$file_num" ]; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg" >>"$LOG_FILE"
	fi
}

log_to_screen() {
	local level=$1
	local msg=$2
	local screen_num
	screen_num=$(get_level_num "$LOG_LEVEL_SCREEN")
	local msg_num
	msg_num=$(get_level_num "$level")
	if [ "$msg_num" -ge "$screen_num" ]; then
		local color=""
		case $level in
		error) color=$RED ;;
		warn) color=$YELLOW ;;
		info) color=$GREEN ;;
		debug) color=$BLUE ;;
		esac
		echo -e "${color}$msg${NC}"
	fi
}

log() {
	local level=$1
	local msg=$2
	log_to_screen "$level" "$msg"
	log_to_file "$level" "$msg"
}

# Function to check if running as root
check_root() {
	log debug "Checking root status..."
	if [[ $EUID -ne 0 ]]; then
		log error "This script must be run as root (use sudo)."
		return 1
	fi
	log info "Root check passed."
}

# Function to check if running on Debian or Ubuntu
check_os() {
	log debug "Checking OS..."
	local os
	os=$(lsb_release -i -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
	if [[ $os != "debian" && $os != "ubuntu" ]]; then
		log error "This script only works on Debian or Ubuntu. Detected: $os"
		return 1
	fi
	log info "OS check passed: $os"
}

# Function to check architecture and set STORCLI command
check_arch() {
	log debug "Checking architecture..."
	local uname_arch
	uname_arch=$(uname -m)
	if [[ $uname_arch == "x86_64" ]]; then
		ARCH="AMD64"
	elif [[ $uname_arch == "aarch64" ]]; then
		ARCH="ARM64"
	else
		log error "Unsupported architecture: $uname_arch"
		return 1
	fi
	log info "Architecture: $ARCH"
}

# Function to download and extract the firmware bundle to WORK_DIR
download_firmware_bundle() {
	log info "Downloading firmware bundle to $WORK_DIR..."
	if ! cd "$WORK_DIR"; then
		log error "Failed to cd to $WORK_DIR"
		return 1
	fi
	if ! curl --location --fail --show-error "${DOWNLOAD_BUNDLE_URL}" --output bundle.tar.gz; then
		log error "Failed to download firmware bundle"
		return 1
	fi

	log info "Extracting firmware bundle..."
	if ! tar -xzf bundle.tar.gz --strip-components=1; then
		log error "Failed to extract firmware bundle"
		return 1
	fi

	log debug "Directory structure in $WORK_DIR:"
	if command -v tree &>/dev/null; then
		local tree_output
		tree_output=$(tree -a -L 5 2>/dev/null || echo "tree failed")
		log debug "$tree_output"
	else
		local find_output
		find_output=$(find . -maxdepth 2 -type f | head -10 2>/dev/null || echo "find failed")
		log debug "$find_output"
	fi

	log debug "Cleaning up download bundle"
	rm -f bundle.tar.gz || log warn "Failed to remove bundle.tar.gz"

	if ! cd - >/dev/null; then
		log warn "Failed to cd back from $WORK_DIR"
	fi
}

# Function to install the correct storcli deb file from WORK_DIR
install_storcli() {
	log info "Installing STORCLI for $ARCH..."
	local ref="${ARCH}_FILE_STORCLI"
	local deb_file="${!ref}"
	local deb_path="$WORK_DIR/$deb_file"
	if [ ! -f "$deb_path" ]; then
		log error "STORCLI deb file not found: $deb_path"
		local tree_output
		tree_output=$(tree -a -L 5 "$WORK_DIR" 2>/dev/null || echo "tree failed")
		log debug "$tree_output"
		return 1
	fi
	log info "Installing STORCLI from $deb_path"
	if ! dpkg -i "$deb_path"; then
		log error "Failed to install STORCLI. Fixing dependencies..."
		apt-get install -f -y || log error "Failed to fix dependencies"
		return 1
	fi
	log info "STORCLI installation completed"

	# Set STORCLI_CMD after installation
	if [ -x "/opt/MegaRAID/storcli/storcli64" ]; then
		STORCLI_CMD="/opt/MegaRAID/storcli/storcli64"
	elif [ -x "/opt/MegaRAID/storcli/storcli" ]; then
		STORCLI_CMD="/opt/MegaRAID/storcli/storcli"
	else
		# Default fallback.
		STORCLI_CMD="storcli"
	fi
	log debug "Using STORCLI_CMD: $STORCLI_CMD"
}

# Function to show SAS cards using storcli
show_cards() {
	log info "Showing SAS cards with $STORCLI_CMD:"
	if ! "$STORCLI_CMD" /c0 show all; then
		log error "Failed to show SAS cards"
		return 1
	fi
	log info "Press any key to continue..."
	read -r -p "Press any key to continue" -n 1 -s
	echo
}

# Function to flash the card firmware
flash_card() {
	log info "Flashing the card firmware..."
	local ref="${ARCH}_FILE_FIRMWARE"
	local fw_file="${!ref}"
	local firmware_path="$WORK_DIR/$fw_file"
	if [ ! -f "$firmware_path" ]; then
		log error "Firmware file not found: $firmware_path"
		return 1
	fi
	local cmd=("$STORCLI_CMD" "/c0" "download" "file=$firmware_path")
	log debug "Running: ${cmd[*]}"
	if ! "${cmd[@]}"; then
		log error "Failed to flash the card firmware"
		return 1
	fi
	log info "Card firmware flashing completed"
	log info "Press any key to continue..."
	read -r -p "Press any key to continue" -n 1 -s
	echo
}

# Function to flash the BIOS using storcli (optional)
flash_efi_bios() {
	local ref="${ARCH}_FILE_BIOS"
	local bios_file="${!ref}"
	if [[ -z $bios_file ]]; then
		log info "No BIOS file defined for $ARCH, skipping BIOS flash"
		return 0
	fi
	local bios_path="$WORK_DIR/$bios_file"
	if [ ! -f "$bios_path" ]; then
		log error "BIOS file not found: $bios_path"
		return 1
	fi
	log info "Flashing the BIOS..."
	local cmd=("$STORCLI_CMD" "/c0" "download" "bios" "file=$bios_path")
	log debug "Running: ${cmd[*]}"
	if ! "${cmd[@]}"; then
		log error "Failed to flash the BIOS"
		return 1
	fi
	log info "BIOS flashing completed"
	log info "Press any key to continue..."
	read -r -p "Press any key to continue" -n 1 -s
	echo
}

# Function to flash the PSOC catalog file
flash_catalog() {
	log info "Flashing the PSOC catalog file..."
	local ref="${ARCH}_FILE_PSOC"
	local cat_file="${!ref}"
	local catalog_path="$WORK_DIR/$cat_file"
	if [ ! -f "$catalog_path" ]; then
		log error "Catalog file not found: $catalog_path"
		return 1
	fi
	local cmd=("$STORCLI_CMD" "/c0" "download" "psoc" "file=$catalog_path")
	log debug "Running: ${cmd[*]}"
	if ! "${cmd[@]}"; then
		log error "Failed to flash the PSOC catalog file"
		return 1
	fi
	log info "PSOC catalog flashing completed"
	log info "Press any key to continue..."
	read -r -p "Press any key to continue" -n 1 -s
	echo
}

#########################
# Main
#########################

main() {

	log info "Starting $SCRIPT_NAME (log: $LOG_FILE)"

	trap cleanup EXIT

	parse_args "$@" || {
		log error "Invalid arguments"
		exit 1
	}

	check_root || {
		log error "Root privileges required"
		exit 2
	}

	check_os || {
		log error "Unsupported OS"
		exit 3
	}

	check_arch || {
		log error "Unsupported architecture"
		exit 4
	}

	download_firmware_bundle || {
		log error "Failed to download firmware bundle"
		exit 99
	}

	install_storcli || {
		log error "Failed to install storcli"
		exit 5
	}

	# Update STORCLI_CMD after install
	check_arch

	show_cards || {
		log error "Failed to show cards"
		exit 6
	}

	flash_card || {
		log error "Failed to flash card firmware"
		exit 7
	}

	flash_efi_bios || {
		log error "Failed to flash BIOS"
		exit 8
	}

	flash_catalog || {
		log error "Failed to flash PSOC catalog"
		exit 9
	}

	log info "$SCRIPT_NAME has finished. Reboot recommended to apply changes."
	read -p "Reboot now? (y/n): " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		log info "Rebooting system..."
		reboot
	fi
}

main "$@"
