#!/usr/bin/env bash

#########################
# Name: bootstrap.sh
# Description: Loads the correct script based on the OS.
#########################

set -e
set -u
set -o pipefail

clear

##########
# Variables
##########

### Common ###

SCRIPT=${0##*/}
SCRIPT_DIR=${0%/*}

export LOG_DESTINATION="stdout"
export LOG_DIR="$(mktemp -d)"
export LOG_FILE="${LOG_DIR}/${SCRIPT}.log"

export LOG_LEVEL="DEBUG"

### Debian ###

# TODO

### NixOS ###

# The first disk (required)
export NIX_CONFIG_INST_DISK_1="/dev/nvme0n1"

# The second disk (optional)
#export NIX_CONFIG_INST_DISK_2="/dev/nvme0n2"

# The size of the UEFI System Partition in MB
export NIX_CONFIG_INST_PARTSIZE_UESP=1024

# The size of the boot partition in GB
export NIX_CONFIG_INST_PARTSIZE_BOOT=4

# The size of the root pool in GB. If set to '0' will use all remaining space.
export NIX_CONFIG_INST_PARTSIZE_ROOT=0

# The size of the swap parition in GB.
export NIX_CONFIG_INST_PARTSIZE_SWAP=64

# Whether to use swap or not.
export NIX_CONFIG_INST_ENABLE_SWAP=TRUE

# Whether to enable encryption or not.
export NIX_CONFIG_INST_ENABLE_ENCRYPTION=TRUE

# Whether to enable impermanence or not.
export NIC_CONFIG_INST_ENABLE_IMPERMANENCE=FALSE

# The hostname will be requested from the user.
export NIX_CONFIG_INST_HOSTNAME

##########
# Functions
##########

if [[ -f "${SCRIPT_DIR}/common.sh" ]];
then
	source "${SCRIPT_DIR}/common.sh"
else
	echo "Unable to import common functions from ${SCRIPT_DIR}"
	exit 1
fi

##########
# Main
##########

writeLog "DEBUG" "Started ${SCRIPT}"

PROMPT="Enter the hostname for the system and press ENTER: "
read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_HOSTNAME
echo -e "\n"

if [[ "${#NIX_CONFIG_INST_HOSTNAME}" -lt 1 ]];
then
	writeLog "ERROR" "Hostname need to be more than 1 character."
	exit 1
else
	export NIX_CONFIG_INST_HOSTNAME
fi

detectOS || {
	writeLog "ERROR" "Failed to determine the Operating System!"
	exit 1
}

writeLog "INFO" "Operating System: ${OS_NAME}"

case "${OS_NAME}" in

	"debian" )

		"./${SCRIPT_DIR}/debian.sh"

	;;

	"nixos" )
		
		"./${SCRIPT_DIR}/nixos.sh"

	;;

	* )

		msg "Unsupported Operating System."
		exit 1

	;;

esac

writeLog "DEBUG" "Finished ${SCRIPT}"
