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

export LOG_DESTINATION="both"
export LOG_DIR
LOG_DIR="$(mktemp -d)"
export LOG_FILE="${LOG_DIR}/${SCRIPT}.log"

export LOG_LEVEL="DEBUG"

### Debian ###

# TODO

### NixOS ###

# The first disk (required)
export NIX_CONFIG_INST_DISK_1

# The second disk (optional)
export NIX_CONFIG_INST_DISK_2

# The size of the UEFI System Partition in MB
export NIX_CONFIG_INST_PARTSIZE_UESP=1024

# The size of the boot partition in GB
export NIX_CONFIG_INST_PARTSIZE_BOOT=4

# The size of the root pool in GB. If set to '0' will use all remaining space.
export NIX_CONFIG_INST_PARTSIZE_ROOT=0

# The size of the swap parition in GB.
export NIX_CONFIG_INST_PARTSIZE_SWAP=64

# Whether to use swap or not.
export NIX_CONFIG_INST_ENABLE_SWAP=FALSE

# Whether to enable encryption or not.
export NIX_CONFIG_INST_ENABLE_ENCRYPTION=FALSEfdis

# Whether to enable impermanence or not.
export NIC_CONFIG_INST_ENABLE_IMPERMANENCE=FALSE

# The hostname will be requested from the user.
export NIX_CONFIG_INST_HOSTNAME

##########
# Functions
##########

if [[ -f "${SCRIPT_DIR}/common.sh" ]];
then
	# shellcheck source=scripts/common.sh
	source "${SCRIPT_DIR}/common.sh"
else
	echo "Unable to import common functions from ${SCRIPT_DIR}"
	exit 1
fi

##########
# Main
##########

writeLog "DEBUG" "Started ${SCRIPT}, writing log to ${LOG_FILE}"

echo -e "\n"
PROMPT="REQUIRED: Enter the desired hostname for the system and press ENTER: "
read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_HOSTNAME
echo -e "\n"

PROMPT="REQUIRED: Enter the first disk name including the /dev portion: "
read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_DISK_1
echo -e "\n"

PROMPT="OPTIONAL: Enter the second mirror disk name including the /dev portion: "
read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_DISK_2
echo -e "\n"

PROMPT="OPTIONAL: If you are using proxy, enter it now including the http prefix: "
read -p "${PROMPT}" -n 30 -r NIX_CONFIG_PROXY_SERVER
echo -e "\n"

if [[ ! "${NIX_CONFIG_PROXY_SERVER}" == "EMPTY" ]];
then

	export HTTP_PROXY="${NIX_CONFIG_PROXY_SERVER}"
	export HTTPS_PROXY="${NIX_CONFIG_PROXY_SERVER}"
	
	export http_proxy="${NIX_CONFIG_PROXY_SERVER}"
	export https_proxy="${NIX_CONFIG_PROXY_SERVER}"

fi

# Checking for internet connectivity
if echo -e "GET https://nixos.org HTTP/1.0\n\n" | nc nixos.org 443 > /dev/null 2>&1;
then

	writeLog "INFO" "Verified connection to nixos.org"

else

	writeLog "ERROR" "Failed to connect to nixos.org, do you have a working connection?"

	writeLog "WARN" "Perhaps you need to setup your IP address. For example;"

	echo "sudo ifconfig down <INTERFACE>"
	echo "sudo ifconfig <INTERFACE> <IP_ADDRESS> netmask <NETMASK>"
	echo "sudo ifconfig up <INTERFACE>"
	echo "route add default gw <IP_ADDRESS> <INTERFACE>"
	echo "echo nameserver <DNS> | tee -a /etc/resolv.conf"

	exit 1

fi

if [[ "${#NIX_CONFIG_INST_HOSTNAME}" -lt 1 ]];
then
	writeLog "ERROR" "Hostname need to be more than 1 character."
	exit 1
else
	export NIX_CONFIG_INST_HOSTNAME
fi

if [[ "${NIX_CONFIG_INST_DISK_1:-EMPTY}" == "EMPTY" ]];
then

	writeLog "ERROR" "You need to at least provide a single disk to install on."
	exit 1

fi

detectOS || {
	writeLog "ERROR" "Failed to determine the Operating System!"
	exit 1
}

writeLog "INFO" "Operating System: ${OS_NAME}"

case "${OS_NAME}" in

	"debian" )

		# shellcheck source=scripts/debian.sh
		"./${SCRIPT_DIR}/debian.sh"

	;;

	"nixos" )

		# shellcheck source=scripts/nixos.sh		
		"./${SCRIPT_DIR}/nixos.sh"

	;;

	* )

		msg "Unsupported Operating System."
		exit 1

	;;

esac

writeLog "DEBUG" "Finished ${SCRIPT}"
