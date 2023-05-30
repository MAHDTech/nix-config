#!/usr/bin/env bash

##################################################
# Name: rust
# Description: Assorted Rust functions
##################################################

function updateRust() {

	local DIR="/tmp"
	local FILE="rustup.lock"
	local LOCK="${DIR}/${FILE}"

	writeLog "DEBUG" "Rustup lock file ${LOCK}"

	if checkBin rustup >/dev/null 2>&1; then

		# If the lock file is stale delete it.
		find "${DIR}" -name "${FILE}" -type f -mmin +1440 -delete 2>/dev/null

		# Ensure there is no existing rustup.lock
		if [[ ! -f ${LOCK} ]]; then

			touch "${LOCK}" || {
				writeLog "ERROR" "Failed to create rustup lock file"
				return 1
			}

			writeLog "INFO" "Checking for Rust updates"

			if ! grep -q "Update available" <(RUSTUP_USE_CURL=1 rustup check); then

				writeLog "INFO" "Rust toolchain is up to date"

			else

				writeLog "INFO" "Updating Rust toolchain"
				rustup update

			fi

			writeLog "INFO" "Removing rustup update lock"
			rm -f "${LOCK}" ||
				{
					writeLog "ERROR" "Failed to remove rustup update lock"
					exit 1
				}

		else

			writeLog "DEBUG" "Skipping Rust update check as lock file was found."

		fi

	else

		writeLog "WARNING" "Rustup is not installed or not available in the PATH"
		return 1

	fi

	return 0

}

function configureRustup() {

	# Dodgy hack to work around using shared dotfiles across OS

	local OS_FAMILY="${OS_FAMILY:=UNKNOWN}"
	local RUSTUP_TARGETS=(
		wasm32-unknown-unknown
	)

	# Add any specific OS family toolchains.
	case "${OS_FAMILY,,}" in

	"linux")
		rustup default stable >/dev/null 2>&1
		;;

	"darwin")
		rustup default stable >/dev/null 2>&1
		;;

	*)
		rustup default stable >/dev/null 2>&1
		;;

	esac

	for TARGET in ${RUSTUP_TARGETS[*]}; do

		if grep -q "${TARGET} (installed)" <(rustup target list); then

			writeLog "DEBUG" "Rust toolchain target ${TARGET} already installed"

		else
			writeLog "INFO" "Installing Rust toolchain target ${TARGET}"

			rustup target add ${TARGET} || {
				writeLog "ERROR" "Failed to add target toolchain ${TARGET}"
				return 1
			}

		fi

	done

	# Show the currently installed and configured toolchains.
	rustup show

	return 0

}
