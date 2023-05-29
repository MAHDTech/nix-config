#!/usr/bin/env bash

##################################################
# Name: .shrc
# Description: Executed by non-login shells.
##################################################

# Bash notes
#   Reference:      - https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
#   .bash_profile   - Read during interactive login shell or --login
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
	"/var/lib/flatpak/exports/share"
	"${HOME}/.local/share/flatpak/exports/share"
	"${HOME}/CodeQL/codeql"
	"${HOME}/CodeQL/bin"
	"${HOME}/go/bin"
	"${HOME}/.pulumi/bin"
	"${HOME}/.krew/bin"
	"${HOME}/.cargo/bin"
	"${HOME}/.local/bin/scripts"
	"${HOME}/.local/bin"
	"${HOME}/bin"
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

*i*) ;;

*) return 0 ;;

esac

if [ -z "$PS1" ]; then

	return 0

fi

#########################
# Import custom functions
#########################

function import_functions_dotfiles() {

	if [[ -d ${DOTFILES} ]]; then

		# Import these dependencies in order.
		IMPORTS=(
			"logging.sh"
			"os.sh"
			"variables.sh"
			"environment.sh"
		)

		for FILE in "${IMPORTS[@]}"; do
			if [[ -f "${DOTFILES}/${FILE}" ]]; then
				# shellcheck disable=1090
				source "${DOTFILES}/${FILE}"
			fi
		done

		# Determine the OS for later use.
		detectOS || {
			return 1
		}

		for FILE in $(find "${DOTFILES}" -maxdepth 1 -type f -o -type l | sort -V); do
			# shellcheck disable=1090
			source "${FILE}"
		done

	fi

}

function import_functions_environment() {

	if [[ -d ${ENVFILES} ]]; then

		# Source the special environment file if its present
		# shellcheck source=${HOME}/.config/environment/variables
		if [[ -f "${ENVFILES}/variables.sh" ]]; then

			source "${ENVFILES}/variables.sh" || {
				writeLog "WARN" "Failed to source local environment variable overrides."
				return 1
			}

		elif [[ -f "${DOTFILES}/environment.sh" ]]; then

			writeLog "INFO" "Copying environment template to ${ENVFILES}/variables.sh"
			cat "${DOTFILES}/environment.sh" >"${ENVFILES}/variables.sh" || {
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

		if [[ -f "${DOTFILES}/environment.sh" ]]; then

			writeLog "INFO" "Copying environment template to ${ENVFILES}/variables.sh"
			cat "${DOTFILES}/environment.sh" >"${ENVFILES}/variables.sh" || {
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

if [[ ${OS_LAYER:-UNKNOWN} == "UNKNOWN" ]]; then
	writeLog "START" "Loading dotfiles for ${OS_FAMILY} ${OS_NAME} ${OS_VER}"
else
	writeLog "START" "Loading dotfiles for ${OS_FAMILY} ${OS_NAME} ${OS_VER} running on ${OS_LAYER}"
fi

# Import environment specific settings that override defaults.
import_functions_environment || {
	echo "Failed to re-import required environment settings!"
	return 1
}

if [[ ! -f "${ENVFILES}/wireless.env.tmpl" ]]; then
	writeLog "INFO" "Creating wpa_supplicant template"

	cat <<-EOF >>"${ENVFILES}/wireless.env.tmpl"
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
if ! shopt -oq posix; then
	if [[ -f /usr/share/bash-completion/bash_completion ]]; then
		writeLog "INFO" "Sourcing bash completion from usr share"
		source /usr/share/bash-completion/bash_completion
	elif [[ -f /etc/bash_completion ]]; then
		writeLog "INFO" "Sourcing bash completion from etc"
		. /etc/bash_completion
	elif shopt -q progcomp &>/dev/null; then
		writeLog "INFO" "Enabling programmable completion for bash"
		. "@bash-completion@/etc/profile.d/bash_completion.sh"
		nullglobStatus=$(shopt -p nullglob)
		shopt -s nullglob
		for MODULE in "@out@/etc/bash_completion.d/"* "@out@/share/bash-completion/completions/"*; do
			. "${MODULE}"
		done
		eval "$nullglobStatus"
		unset nullglobStatus p MODULE
	else
		writeLog "WARN" "Unable to source bash completion, is the package installed?"
	fi
fi

if checkBin ls-colors-bash.sh; then
	source ls-colors-bash.sh
fi

#########################
# Setup PATH
#########################

writeLog "DEBUG" "Current PATH: $PATH"

# All all the provided folders to the PATH
for FOLDER in "${FOLDERS[@]}"; do

	if [ -d "${FOLDER}" ]; then
		addPath "${FOLDER}"
	else
		writeLog "DEBUG" "Folder ${FOLDER} doesn't exist"
	fi

done

export PATH

writeLog "DEBUG" "New PATH: $PATH"

#########################
# Yubikey
#########################

if [[ ${YUBIKEY_ENABLED:-FALSE} == "TRUE" ]]; then
	load_yubikey || {
		writeLog "WARN" "Failed to setup YubiKey for SSH"
	}
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

if [[ ${RUST_ENABLED:-TRUE} == "TRUE" ]]; then

	if checkBin rustup; then

		configureRustup || {
			writeLog "ERROR" "Failed to configure rustup"
		}

		updateRust || {
			writeLog "ERROR" "Failed to update Rust"
		}

		if [[ -f "${HOME}/.cargo/env" ]]; then
			writeLog "INFO" "Sourcing Cargo Environment"
			. "${HOME}/.cargo/env"
		fi

	fi

fi

#########################
# Fortune cookies
#########################

if checkBin figlet; then
	figlet dotfiles
fi

if checkBin fortune; then
	fortune
fi

#########################
# Setup a trap
#########################

trap exit_bash_session SIGHUP

writeLog "INFO" "Completed loading .shrc"
