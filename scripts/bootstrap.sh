#!/usr/bin/env bash

#########################
# Name: bootstrap.sh
# Description: Loads the correct script based on the OS.
#########################

clear

set -euao pipefail

#########################
# Variables
#########################

SCRIPT=${0##*/}
SCRIPT_DIR=${0%/*}

export LOG_DESTINATION="both"
export LOG_DIR
LOG_DIR="$(mktemp -d)"
export LOG_FILE="${LOG_DIR}/${SCRIPT}.log"

export LOG_LEVEL="DEBUG"

# Allow unfree packages.
export NIXPKGS_ALLOW_UNFREE=1

# Cachix auth token
export CACHIX_AUTH_TOKEN
export CACHIX_CACHE_NAME

# Flake location assumes local but can be overridden
export FLAKE_LOCATION

#########################
# Debian
#########################

# If you want the Nix daemon installed directly.
export INSTALL_NIX_ON_DEBIAN="${INSTALL_NIX_ON_DEBIAN:-TRUE}"

# The supported old releases to upgrade from.
export DEBIAN_VERSION_CODENAMES=("buster" "bullseye")

# The distro to update the container to
export DEBIAN_VERSION_CODENAME="${DEBIAN_VERSION_CODENAME:-bookworm}"

#########################
# NixOS
#########################

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

# The size of the swap partition in GB.
export NIX_CONFIG_INST_PARTSIZE_SWAP=64

# Whether to use swap or not.
export NIX_CONFIG_INST_ENABLE_SWAP=FALSE

# Whether to enable encryption or not.
export NIX_CONFIG_INST_ENABLE_ENCRYPTION=FALSE

# Whether to enable impermanence or not.
export NIX_CONFIG_INST_ENABLE_IMPERMANENCE=FALSE

# The hostname will be requested from the user.
export NIX_CONFIG_INST_HOSTNAME

##########
# Functions
##########

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
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

# Re-run this script as root if required.
if [[ ${EUID} -ne 0 ]]; then
	writeLog "INFO" "Elevating script to root user."
	#exec sudo -E -s "$0" "$@"
	sudo --bell --validate
else
	writeLog "INFO" "Executing script as root user."
fi

echo -e "\n"
PROMPT="REQUIRED: Enter the flake location and press ENTER. Defaults to the current directory '.' : "
read -p "${PROMPT}" -n 30 -r FLAKE_LOCATION
echo -e "\n"

PROMPT="OPTIONAL: If you are using proxy, enter it now including the http prefix: "
read -p "${PROMPT}" -n 30 -r NIX_CONFIG_PROXY_SERVER
echo -e "\n"

PROMPT="OPTIONAL: If you are using Cachix, enter the cache name to use: "
read -p "${PROMPT}" -n 30 -r CACHIX_CACHE_NAME
echo -e "\n"

PROMPT="OPTIONAL: If you are using Cachix, enter you're auth token: "
read -p "${PROMPT}" -n 30 -r CACHIX_AUTH_TOKEN
echo -e "\n"

if [[ ${NIX_CONFIG_PROXY_SERVER} != "EMPTY" ]]; then

	export HTTP_PROXY="${NIX_CONFIG_PROXY_SERVER}"
	export HTTPS_PROXY="${NIX_CONFIG_PROXY_SERVER}"

	export http_proxy="${NIX_CONFIG_PROXY_SERVER}"
	export https_proxy="${NIX_CONFIG_PROXY_SERVER}"

fi

# Checking for internet connectivity
if type curl >/dev/null 2>&1; then

	writeLog "DEBUG" "curl is available"

	NET_CHECK_COMMAND=(
		"curl"
		"https://nixos.org"
	)

elif type nc >/dev/null 2>&1; then

	writeLog "DEBUG" "netcat is available"

	NET_CHECK_COMMAND=(
		"echo"
		"-e"
		"GET"
		"https://nixos.org HTTP/1.0\n\n"
		"|"
		"nc"
		"nixos.org"
		"443"
	)

else
	writeLog "ERROR" "Both curl and netcat are not installed."
	exit 1
fi

if "${NET_CHECK_COMMAND[@]}" >/dev/null 2>&1; then

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

detectOS || {
	writeLog "ERROR" "Failed to determine the Operating System!"
	exit 1
}

writeLog "INFO" "Operating System: ${OS_NAME}"

case "${OS_NAME}" in

"debian")

	# shellcheck source=scripts/debian.sh
	source "./${SCRIPT_DIR}/debian.sh"

	;;

"nixos")

	echo -e "\n"
	PROMPT="REQUIRED: Enter the desired hostname for the system and press ENTER: "
	read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_HOSTNAME
	echo -e "\n"

	if [[ ${#NIX_CONFIG_INST_HOSTNAME} -lt 1 ]]; then
		writeLog "ERROR" "Hostname need to be more than 1 character."
		exit 1
	else
		export NIX_CONFIG_INST_HOSTNAME
	fi

	PROMPT="REQUIRED: Enter the first disk name including the /dev portion: "
	read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_DISK_1
	echo -e "\n"

	PROMPT="OPTIONAL: Enter the second mirror disk name including the /dev portion: "
	read -p "${PROMPT}" -n 30 -r NIX_CONFIG_INST_DISK_2
	echo -e "\n"

	if [[ ${NIX_CONFIG_INST_DISK_1:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "You need to at least provide a single disk to install on."
		exit 1
	fi

	# shellcheck source=scripts/nixos.sh
	source "./${SCRIPT_DIR}/nixos.sh"

	;;

*)

	msg "Unsupported Operating System."
	exit 1

	;;

esac

writeLog "DEBUG" "Finished ${SCRIPT}"

exit 0
