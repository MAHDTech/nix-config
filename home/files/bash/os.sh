#!/usr/bin/env bash

################################################################################
# Name: os
# Description: Common functions for OS detection
################################################################################

function detectOS() {

	OS_FAMILY="${OS_FAMILY:=UNKNOWN}"
	OS_NAME="${OS_NAME:=UNKNOWN}"
	OS_VER="${OS_VER:=UNKNOWN}"
	OS_LAYER="${OS_LAYER:=UNKNOWN}"

	writeLog "DEBUG" "Determining the OS Name and Version"

	OS_FAMILY=$(uname)

	if [[ -f /etc/os-release ]]; then

		# freedesktop.org and systemd
		# shellcheck disable=SC1091
		. /etc/os-release
		OS_NAME=$ID
		OS_VER=$VERSION_ID

	elif type lsb_release >/dev/null 2>&1; then

		# linuxbase.org
		OS_NAME=$(lsb_release -si)
		OS_VER=$(lsb_release -sr)

	elif [[ -f /etc/lsb-release ]]; then

		# For some versions of Debian/Ubuntu without lsb_release command
		# shellcheck disable=SC1091
		. /etc/lsb-release
		OS_NAME=$DISTRIB_ID
		OS_VER=$DISTRIB_RELEASE

	elif [[ -f /etc/debian_version ]]; then

		# Older Debian/Ubuntu/etc.
		OS_NAME=Debian
		OS_VER=$(cat /etc/debian_version)

	elif [[ -f /etc/SuSe-release ]]; then

		# Older SuSE/etc.
		OS_NAME=$(head -n 1 /etc/SuSE-release)
		OS_VER=$(sed -n 2p /etc/SuSE-release | cut -f2 -d'=' | tr -d '[:space:]')

	elif [[ -f /etc/redhat-release ]]; then

		# Older Red Hat, CentOS, etc.
		OS_NAME=$(cat /etc/redhat-release)
		OS_VER="Old Release"

	else

		# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
		OS_NAME=$(uname -s)
		OS_VER=$(uname -r)

	fi

	# Determine if the OS is running on one of the non-standard setups like WSL, ChromeOS or Silverblue

	if grep -E -qi "Microsoft|WSL" /proc/version; then

		OS_LAYER="WSL"

	elif grep -qi "Chromium" /proc/version; then

		OS_LAYER="Crostini"

	elif [[ -f /etc/os-release ]]; then

		# shellcheck disable=SC1091
		. /etc/os-release
		OS_LAYER="${VARIANT_ID:=UNKNOWN}"

	fi

	if [[ ${OS_LAYER:-UNKNOWN} == "UNKNOWN" ]]; then
		writeLog "DEBUG" "Operating System: ${OS_FAMILY} ${OS_NAME} ${OS_VER}"
	else
		OS_LAYER="${OS_LAYER,,}"
		writeLog "DEBUG" "Operating System: ${OS_FAMILY} ${OS_NAME} ${OS_VER} running on ${OS_LAYER}"
	fi

	export OS_FAMILY
	export OS_NAME
	export OS_VER
	export OS_LAYER

	return 0

}
