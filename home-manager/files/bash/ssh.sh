#!/usr/bin/env bash

##################################################
# Name: ssh
# Description: Contains ssh related functions
##################################################

function load_yubikey() {

	#########################
	# SSH
	#
	# NOTES:
	#
	#	- First time setup.
	#		mkdir -p ~/.ssh/keys
	#		ssh-keygen \
	#			-C MAHDTech@saltlabs.tech \
	#			-t ed25519-sk \
	#			-O resident \
	#			-O verify-required \
	#			-f ~/.ssh/keys/id_ed25519_sk
	#
	#	- On new systems;
	#		ssh-keygen -K
	#
	#########################

	# If running in VSCode shell, return immediately.
	if [[ ${ENVIRONMENT:-EMPTY} == "vscode" ]]; then
		writeLog "WARN" "VSCode Shell detected, skipping YubiKey interactive loader."
		return 0
	fi

	# HACK: Manually set SSH_AUTH_SOCK if not already set.
	export _SSH_AUTH_SOCK="/run/user/$(id --user)/keyring/ssh"

	if [[ ${SSH_AUTH_SOCK:-EMPTY} == "EMPTY" ]]; then

		if [[ -S ${_SSH_AUTH_SOCK} ]]; then
			writeLog "DEBUG" "Updating SSH socket location"
			export SSH_AUTH_SOCK="${_SSH_AUTH_SOCK}"
		fi

	fi
	writeLog "INFO" "SSH socket is set to ${SSH_AUTH_SOCK}"

	YUBIKEY_LOADED="FALSE"
	until [[ ${YUBIKEY_LOADED} == "TRUE" ]]; do

		# Detecting YubiKey.
		if ! lsusb | grep -i Yubikey >/dev/null; then

			writeLog "WARN" "YubiKey not detected, unable to load SSH keys."

			PROMPT="YubiKey not detected, plug one in now and hit 'Y' to load, or hit 'N' to skip..."
			read -p "${PROMPT}" -n 1 -r CHOICE
			echo -e "\n"

			if [[ ! ${CHOICE} =~ ^[Yy] ]]; then
				writeLog "WARN" "Cancelling at user request."
				break
			fi

		else

			writeLog "INFO" "Detected connected YubiKey, loading SSH keys"

			if checkBin figlet; then
				figlet YubiKey SSH
			fi

			ssh-add -K
			YUBIKEY_LOADED="TRUE"

		fi

	done

	return 0

}