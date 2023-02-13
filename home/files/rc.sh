#!/usr/bin/env bash

##################################################
# Name: .shrc
# Description: Executed by non-login shells.
##################################################

# Bash notes
#   Reference:      - https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
#   .bash_profile   - Read during interative login shell or --login
#   .bashrc         - Read during interactive non-login shell
#   .bash_logout    - Read during logout

# NOTE: This file is merged into .bashrc by Nix home manager.

#set -x
#set -euo pipefail

#########################
# Global variables
#########################

#SCRIPT=${0##*/}
SCRIPT="dotfiles"
DOTFILES="${HOME}/.config/bash"
ENVFILES="${HOME}/.config/environment"

# Logging
export LOG_DESTINATION="${LOG_DESTINATION:=all}"
export LOG_DIR="${HOME}/.logs"
export LOG_FILE="${LOG_DIR}/${SCRIPT}.log"
export LOG_LEVEL="INFO"

# Folders to add in the PATH
FOLDERS=(
	"/usr/sbin"
	"/usr/local/sbin"
	"/usr/bin"
	"/usr/local/bin"
	"/snap/bin"
	"${HOME}/.rvm/bin"
	"${HOME}/.radicle/bin"
	"${HOME}/appimage"
	"${HOME}/CodeQL/codeql"
	"${HOME}/CodeQL/bin"
	"${HOME}/.local/bin"
	"${HOME}/go/bin"
	"${HOME}/.krew/bin"
	"${HOME}/.cargo/bin"
	"${HOME}/bin"
	"${HOME}/.pulumi/bin"
	"${HOME}/.nix-profile/bin"
)

# A list of required binaries for the dotfiles to work correctly
REQ_BINS=(
	awk
	cat
	curl
	cut
	date
	defaults
	dirname
	echo
	fgrep
	gettext
	git
	grep
	pgrep
	sed
	sleep
	split
	ssh
	tr
)

#########################
# Interactive test
#########################

case $- in

	*i* ) ;;

	* ) return 0 ;;

esac

if [ -z "$PS1" ];
then

	return 0

fi

#########################
# Import custom functions
#########################

function import_functions_dotfiles() {

	if [[ -d "${DOTFILES}" ]];
	then

		# Import these dependencies in order.
		IMPORTS=(
			"logging.sh"
			"os.sh"
			"variables.sh"
			"environment.sh"
		)

		for FILE in "${IMPORTS[@]}";
		do
			if [[ -f "${DOTFILES}/${FILE}" ]];
			then
				# shellcheck disable=1090
				source "${DOTFILES}/${FILE}"
			fi
		done

		# Determine the OS for later use.
		detectOS || {
			return 1
		}

		for FILE in $(find "${DOTFILES}" -maxdepth 1 -type f -o -type l | sort -V);
		do
			# shellcheck disable=1090
			source "${FILE}"
		done

	fi

}

function import_functions_environment() {

	if [[ -d "${ENVFILES}" ]];
	then

		# Source the special environment file if its present
		# shellcheck source=${HOME}/.config/environment/variables
		if [[ -f "${ENVFILES}/variables.sh" ]];
		then

			source "${ENVFILES}/variables.sh" || {
				writeLog "WARN" "Failed to source local environment variable overrides."
				return 1
			}

		elif [[ -f "${DOTFILES}/environment.sh" ]];
		then

			writeLog "INFO" "Copying environment template to ${ENVFILES}/variables.sh"
			cp --force "${DOTFILES}/environment.sh" "${ENVFILES}/variables.sh" || {
				writeLog "WARN" "Failed to copy environment variables template"
				return 1
			}

		else

			writeLog "ERROR" "No environment template file is available!"
			return 1

		fi

	else

		mkdir --parents "${ENVFILES}" || {
			writeLog "WARN" "Failed to create environment folder, unable to source customisations."
			return 1
		}

		if [[ -f "${DOTFILES}/environment.sh" ]];
		then
			cp --force "${DOTFILES}/environment.sh" "${ENVFILES}/variables.sh" || {
				writeLog "WARN" "Failed to copy environment variables template"
				return 1
			}
		fi

	fi

}

import_functions_dotfiles || {
	echo "Failed to import required dotfiles functions!"
	return 1
}

if [[ "${OS_LAYER:-UNKNOWN}" == "UNKNOWN" ]];
then
	writeLog "START" "Loading dotfiles for ${OS_FAMILY} ${OS_NAME} ${OS_VER}"
else
	writeLog "START" "Loading dotfiles for ${OS_FAMILY} ${OS_NAME} ${OS_VER} running on ${OS_LAYER}"
fi

# Import environment specific settings that override defaults.
import_functions_environment || {
	echo "Failed to re-import required environment settings!"
	return 1
}

if [[ ! -f "${ENVFILES}/wireless.env.tmpl" ]];
then
	writeLog "INFO" "Creating wpa_supplicant template"

	cat <<- EOF >> "${ENVFILES}/wireless.env.tmpl"
	# Wireless configuration

	PSK_HOME="PASSWORD_HERE"

	PSK_WORK="PASSWORD_HERE"

	EOF

fi

#########################
# Setup Bash
#########################

shell_options || {
	writeLog "ERROR" "Failed to set Bash Shell options!"
	return 1
}

# Enable auto-completion
if ! shopt -oq posix;
then
	if [[ -f /usr/share/bash-completion/bash_completion ]];
	then
		source /usr/share/bash-completion/bash_completion
	elif [[ -f /etc/bash_completion ]];
	then
		. /etc/bash_completion
	else
		writeLog "WARN" "Unable to source bash completion, is the package installed?"
	fi
fi

if checkBin ls-colors-bash.sh;
then
	source ls-colors-bash.sh
fi

#########################
# Setup PATH
#########################

writeLog "DEBUG" "Current PATH: $PATH"

# All all the provided folders to the PATH
for FOLDER in "${FOLDERS[@]}";
do

	if [ -d "${FOLDER}" ];
	then
		addPath "${FOLDER}"
	else
		writeLog "DEBUG" "Folder ${FOLDER} doesn't exist"
	fi

done

export PATH

writeLog "DEBUG" "New PATH: $PATH"

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

# HACK: Manually set SSH_AUTH_SOCK if not already set.
export _SSH_AUTH_SOCK="/run/user/$(id --user)/keyring/ssh"

if [[ "${SSH_AUTH_SOCK:-EMPTY}" == "EMPTY" ]];
then

    if [[ -S "${_SSH_AUTH_SOCK}" ]];
    then
        writeLog "DEBUG" "Setting default SSH socket location"
        export SSH_AUTH_SOCK="${_SSH_AUTH_SOCK}"
    fi

fi
writeLog "INFO" "SSH socket at ${SSH_AUTH_SOCK}"

YUBIKEY_LOAD="FALSE"
YUBIKEY_MODEL="ID 1050:0407 Yubico.com Yubikey 4/5 OTP+U2F+CCID"

if lsusb | grep "${YUBIKEY_MODEL}" >/dev/null;
then

	writeLog "INFO" "Detected connected YubiKey, loading SSH keys"
	YUBIKEY_LOAD="TRUE"

else

	writeLog "WARN" "YubiKey not detected, unable to load SSH keys"

	PROMPT="YubiKey not detected, plugin now and hit 'Y' to load, or hit 'N' to skip..."
	read -p "${PROMPT}" -n 1 -r CHOICE
	echo -e "\n"

	if [[ "${CHOICE}" =~ ^[Yy] ]];
	then

		writeLog "INFO" "User manually asked for YubiKey SSH to be loaded."
		YUBIKEY_LOAD="TRUE"

	else

		writeLog "WARN" "YubiKey not detected, user skipped SSH key load"

	fi

fi

if [[ "${YUBIKEY_LOAD:-FALSE}" == "TRUE" ]];
then

	if checkBin figlet;
	then
		figlet YubiKey SSH
	fi

	ssh-add -K

fi

#########################
# Wakatime
#########################

checkWakaTime || {
	writeLog "WARN" "Failed to check Wakatime configuration!"
}

#########################
# Rust
#########################

if checkBin rustup;
then

	configureRustup || {
		writeLog "ERROR" "Failed to configure rustup"
	};

	updateRust || {
		writeLog "ERROR" "Failed to update Rust"
	};

	if [[ -f "${HOME}/.cargo/env" ]];
	then
		writeLog "INFO" "Sourcing Cargo Environment"
		. "${HOME}/.cargo/env"
	fi

fi

#########################
# Fortune cookies
#########################

if checkBin figlet;
then
	figlet dotfiles
fi

if checkBin fortune;
then
	fortune
fi

#########################
# Setup a trap
#########################

trap exit_bash_session SIGHUP

writeLog "INFO" "Completed loading .shrc"
