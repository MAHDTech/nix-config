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
				writeLog "DEBUG" "Sourcing ${DOTFILES}/${FILE}"
				# shellcheck disable=1090
				source "${DOTFILES}/${FILE}"
			fi
		done

		# Determine the OS for later use.
		detectOS || {
			writeLog "ERROR" "Failed to determine the Operating System"
			return 1
		}

		for FILE in $(find "${DOTFILES}" -maxdepth 1 -type f -o -type l | sort -V);
		do
			writeLog "DEBUG" "Sourcing ${FILE}"
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
		if [[ -f "${ENVFILES}/variables" ]];
		then

			source "${ENVFILES}/variables" || {
				writeLog "WARN" "Failed to source local environment variables"
				return 1
			}

		elif [[ -f "${ENVFILES}/template" ]];
		then

			writeLog "INFO" "Copying environment template to ${ENVFILES}/variables"
			cp --force "${ENVFILES}/template" "${ENVFILES}/variables"

		else

			writeLog "ERROR" "No environment template file is available!"
			return 1

		fi

	else

		writeLog "WARN" "No environment folder is available, unable to source customisations."

	fi

}

# Import environment specific settings first.
#import_functions_environment || {
#	echo "Failed to import required environment settings!"
#	return 1
#}

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

# Re-import environment specific settings to ensure overrides are in place.
import_functions_environment || {
	echo "Failed to re-import required environment settings!"
	return 1
}

#########################
# Setup Bash
#########################

shell_options || {
	writeLog "ERROR" "Failed to set Bash Shell options!"
	return 1
}

locale_generate || {
	writeLog "ERROR" "Failed to generate the locale"
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
# Nix
#########################

if [[ "${NIX_ENABLED:-FALSE}" == "TRUE" ]];
then

	# Source the Nix profile
	if [[ -f "${NIX_PROFILE_SCRIPT_USER}" ]];
	then

		# Single user mode
		writeLog "INFO" "Sourcing Nix single user profile"

		# shellcheck source=${HOME}/.nix-profile/etc/profile.d/nix.sh
		. "${NIX_PROFILE_SCRIPT_USER}"

	elif [[ -f "${NIX_PROFILE_SCRIPT_MACHINE}" ]];
	then

		# Multi user mode
		writeLog "INFO" "Sourcing Nix multi user profile"

		# shellcheck source=/etc/profile.d/nix.sh
		. "${NIX_PROFILE_SCRIPT_MACHINE}"

	fi

	# Add the required channels to NIX_PATH
	# https://github.com/NixOS/nix/issues/2033
	#export NIX_PATH=${HOME}/.nix-defexpr/channels${NIX_PATH:+:}${NIX_PATH}
	# UPDATE: This is now done from $NIX_PROFILE_SCRIPT_USER

	if checkBin nix-env;
	then

		if [[ "${DOTFILES_UPDATE:-FALSE}" == "TRUE" ]];
		then

			writeLog "INFO" "Updating Nix..."

			nix-channel --update || {
				writeLog "ERROR" "Failed to check Nix channel for updates"
				return 1
			};

			if checkBin home-manager;
			then

				writeLog "INFO" "Nix Home Manager is installed"

				# Home Manager (User)
				HOME_MANAGER_PROFILE="${HOME}/.nix-profile/etc/profile.d/hm-session-vars.sh"

				if [[ -L "${HOME_MANAGER_PROFILE}" ]];
				then

					if [[ -n "$__HM_SESS_VARS_SOURCED" ]];
					then
						writeLog "INFO" "Nix Home Manager profile already sourced"
					else
						writeLog "INFO" "Sourcing Nix Home Manager profile"
						# shellcheck source="${HOME}/.nix-profile/etc/profile.d/hm-session-vars.sh"
						source "${HOME_MANAGER_PROFILE}" || {
							writeLog "ERROR" "Failed to source the Nix Home Manager profile"
						};
					fi

				fi

				home-manager-exec || {
					writeLog "ERROR" "Failed to check for Nix Home Manager updates"
					return 1
				};

			else

				writeLog "WARN" "Home Manager is not installed, skipping update"

			fi

			writeLog "INFO" "Performing Nix garbage collection..."
			nix-collect-garbage || {
				writeLog "ERROR" "Failed to perform Nix garbage collection!"
				return 1
			}

		fi

	else

		writeLog "WARN" "Nix is not installed, unable to update"

	fi

fi

#########################
# SSH
#########################

#PKCS11_LOC="/run/current-system/sw/lib/opensc-pkcs11.so"

# Load SSH keys from any connected smart cards into the agent.
#ssh-add -e ${PKCS11_LOC} || {
#    writeLog "ERROR" "Failed to remove existing PKCS11 keys from SSH agent"
#}

#ssh-add -s ${PKCS11_LOC} || {
#    writeLog "ERROR" "Failed to add PKCS11 keys to SSH agent"
#}

#########################
# dotfiles check
#########################

# Use a local file as an indicator for last run
DOTFILES_LOCK_DIR="/tmp"
DOTFILES_LOCK_FILE="dotfiles.lock"

# Remove the lock after 24 hours
find "${DOTFILES_LOCK_DIR}" \
	-ignore_readdir_race \
	-name "${DOTFILES_LOCK_FILE}" \
	-type f \
	-mmin +1440 \
	-delete \
	2>/dev/null || true

# Start a fresh counter
if [[ ! -f "${DOTFILES_LOCK_DIR}/${DOTFILES_LOCK_FILE}" ]];
then

	writeLog "DEBUG" "Creating dotfiles lock file"

	touch "${DOTFILES_LOCK_DIR}/${DOTFILES_LOCK_FILE}" || {
		writeLog "ERROR" "Failed to create dotfiles lock file!"
	}

	# First run
	writeLog "DEBUG" "Enabling dotfiles for updates"
	DOTFILES_UPDATE="TRUE"

else

	writeLog "DEBUG" "The dotfiles lock file already exists and is not stale"
	DOTFILES_UPDATE="FALSE"

fi

if [[ "${DOTFILES_UPDATE:-FALSE}" == "TRUE" ]];
then

	writeLog "INFO" "The dotfiles are stale, checking for updates..."

	dotfiles fetch || writeLog "ERROR" "Failed to fetch dotfiles"

	dotfiles_update || writeLog "ERROR" "Failed to update dotfiles submodules"

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
# Prompt
#########################

if checkBin starship ;
then

	writeLog "INFO" "Launching Starship"
	unset PS1
	eval "$(starship init bash)"

else

	writeLog "ERROR" "Unable to pimp your Shell as Starship is not installed!"

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
