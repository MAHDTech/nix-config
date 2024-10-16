#!/usr/bin/env bash

##################################################
# Name: ssh
# Description: Contains ssh related functions
##################################################

function ssh_control_master() {
	local SSH_CONTROL_MASTER_DIR="${HOME}/.ssh/control-master"

	if [[ ! -d ${SSH_CONTROL_MASTER_DIR} ]]; then
		mkdir -p "${SSH_CONTROL_MASTER_DIR}" || {
			writeLog "ERROR" "Failed to create SSH Control Master"
			return 1
		}
	fi

	return 0

}

function load_sshSocket() {

	# HACK: Manually set SSH_AUTH_SOCK if not already set.
	export _SSH_AUTH_SOCK
	_SSH_AUTH_SOCK="/run/user/$(id --user)/keyring/ssh"

	# If running in WSL, don't load SSH keys.
	if type ssh.exe >/dev/null 2>&1 || [[ ${OS_LAYER^^} == "WSL" ]]; then

		writeLog "INFO" "Running in WSL, skipping loading SSH keys expecting 1Password to be installed on Windows"
		return 0

	# If the 1Password CLI is installed, assume the SSH Agent is enabled.
	elif type op >/dev/null 2>&1; then

		writeLog "INFO" "Using 1Password SSH Agent Socket"

		#export SSH_AUTH_SOCK="${HOME}/.op/ssh-agent.sock"
		export SSH_AUTH_SOCK="${HOME}/.1password/agent.sock"

	# If there was no existing SSH socket, and the default socket exists, use it.
	elif [[ ${SSH_AUTH_SOCK:-EMPTY} == "EMPTY" ]]; then

		if [[ -S ${_SSH_AUTH_SOCK} ]]; then

			writeLog "DEBUG" "Updating SSH socket location"
			export SSH_AUTH_SOCK="${_SSH_AUTH_SOCK}"

		else

			writeLog "WARN" "No existing SSH auth socket exists, aborting..."
			return 1

		fi

	else

		writeLog "DEBUG" "SSH socket already set to ${SSH_AUTH_SOCK}"

	fi

	writeLog "INFO" "SSH socket is already set to ${SSH_AUTH_SOCK}"
	return 0

}

function load_sshkeys() {

	# If running in VSCode shell, return immediately.
	if [[ ${ENVIRONMENT:-EMPTY} == "vscode" ]]; then
		writeLog "WARN" "VSCode Shell detected, skipping YubiKey interactive loader."
		return 0
	fi

	load_sshSocket || {
		writeLog "WARN" "Failed to setup SSH socket"
		return 1
	}

	ssh-add || {
		writeLog "WARN" "Failed to load SSH keys"
		return 1
	}

	return 0

}

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

	load_sshSocket || {
		writeLog "WARN" "Failed to setup SSH socket"
		return 1
	}

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

			ssh-add -K || {
				writeLog "ERROR" "Failed to load resident SSH keys"
				return 1
			}
			YUBIKEY_LOADED="TRUE"

		fi

	done

	return 0

}
