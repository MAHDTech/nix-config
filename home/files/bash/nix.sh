#!/usr/bin/env bash

##################################################
# Name: nix
# Description: Assorted Nix related functions
##################################################

function DISABLED_nix-uninstall() {

	local NIX_STORE_HOME="/nix"
	local NIX_STORE_CONFIG="/etc/nix"
	local NIX_PROFILE_SCRIPT="${HOME}/.nix-profile/etx/profile.d/nix.sh"

	# Is there an existing /nix dir?
	if [[ -d "${NIX_STORE_HOME}" ]];
	then

		writeLog "INFO" "Uninstalling Nix"

		sudo rm -rf "${HOME}/"{.nix-channels,.nix-defexpr,.nix-profile,.config/nixpkgs} || {
			writeLog "WARNING" "Failed to remove all Nix directories in \$HOME"
		};

		sudo rm -rf /root/{.nix-channels,.nix-defexpr,.nix-profile,.config/nixpkgs} || {
			writeLog "WARNING" "Failed to remove all Nix directories in root"
		};

		sudo rm -f /etc/profile.d/nix.sh* || {
			writeLog "ERROR" "Failed to remove nix.sh profile"
			return 1
		};

		sudo rm -rf "${NIX_STORE_HOME}" || {
			writeLog "ERROR" "Failed to remove Nix Store home"
			return 1
		};

		sudo rm -rf "${NIX_STORE_CONFIG}" || {
			writeLog "ERROR" "Failed to remove Nix Store config"
			return 1
		};

		sudo rm -f "${NIX_PROFILE_SCRIPT}" || {
			writeLog "ERROR" "Failed to remove Nix Profile script"
			return 1
		};

	fi

	return 0

}

function _dotfiles_actions() {

	local ACTION="$1"
	local ACTION="${ACTION,,}"
	shift
	local FLAKE_LOCATION="$1"
	local FLAKE_LOCATION="${FLAKE_LOCATION,,}"
	shift
	local EXTRA_ARGS=("$@")

	case "${OS_NAME:-EMPTY}" in

		"nixos" )

			nixos-rebuild \
				"${ACTION}" \
					--use-remote-sudo \
					--upgrade-all \
					--refresh \
					--allow-dirty \
					--flake "${FLAKE_LOCATION}#" \
					"${EXTRA_ARGS[@]}" || {

						writeLog "ERROR" "Failed to perform NixOS ${ACTION,,}"
						popd > /dev/null || return 1
						return 1

					}

		;;

		* )

			home-manager \
				"${ACTION}" \
				--flake "${FLAKE_LOCATION}" \
				"${EXTRA_ARGS[@]}" || {

					writeLog "ERROR" "Failed to perform Nix Home Manager ${ACTION,,}"
					popd > /dev/null || return 1
					return 1

				}

		;;

	esac

}

function dotfiles() {

	local ACTION="$1"
	local ACTION="${ACTION,,}"
	shift
	local EXTRA_ARGS=("$@")

	local DOTFILES_CONFIG="${DOTFILES_CONFIG:=$HOME/Projects/GitHub/MAHDTech/nix-config}"

	local FLAKE_LOCATION
	local FLAKE_REMOTE="github:MAHDTech/nix-config"
	local FLAKE_LOCAL="."
	local FLAKE_HOME_MANAGER
	FLAKE_HOME_MANAGER="$(printf '%s\n' "$(whoami)"@"$(hostname)")"

	local EXECUTE="FALSE"

	local VALID_ACTIONS=(
		"check"
		"build"
		"test"
		"switch"
		"update"
		"garbage-collect"
	)

	# Check if the action is valid before continuing.
	for VALID_ACTION in "${VALID_ACTIONS[@]}";
	do

		if [[ "$ACTION" == "$VALID_ACTION" ]];
		then
			writeLog "DEBUG" "The action ${ACTION} is valid."
			EXECUTE="TRUE"
			break
		fi

	done

	# Return if the action is invalid.
	if [[ "${EXECUTE}" == "FALSE" ]];
	then

		writeLog "ERROR" "Invalid action: ${ACTION:-NONE}"
		return 1

	fi

	# Change into the dotfiles config directory.
	if [[ -d "${DOTFILES_CONFIG}" ]];
	then

		pushd "${DOTFILES_CONFIG}" > /dev/null || {
			writeLog "Failed to change into ${DOTFILES_CONFIG}"
			return 1
		}

		FLAKE_LOCATION="${FLAKE_LOCAL}"

	else

		writeLog "WARN" "The dotfiles config directory is not present ${DOTFILES_CONFIG}"

		FLAKE_LOCATION="${FLAKE_REMOTE}"

	fi

	case "${OS_NAME:-EMPTY}" in

		"nixos" )

			FLAKE_LOCATION="${FLAKE_LOCATION}#${FLAKE_HOME_MANAGER}"

		;;

		* )

			FLAKE_LOCATION="${FLAKE_LOCATION}#${FLAKE_HOME_MANAGER}"

		;;

	esac

	writeLog "INFO" "Executing ${ACTION} on Nix Flake ${FLAKE_LOCATION}"

	case "${ACTION}" in

		"check" )

			nix flake check \
				--no-build \
				--allow-dirty \
				--keep-going \
				"${EXTRA_ARGS[@]}" || {
					writeLog "WARN" "Failed flake check!"
					return 1
				}

		;;

		"build" )

			_dotfiles_actions "build" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
				writeLog "ERROR" "Failed to build dotfiles"
				return 1
			}

		;;

		"test" )

			_dotfiles_actions "test" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
				writeLog "ERROR" "Failed to test dotfiles"
				return 1
			}

		;;

		"switch" )

			_dotfiles_actions "switch" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
				writeLog "ERROR" "Failed to switch dotfiles"
				return 1
			}

		;;

		"update" )

			case "${OS_NAME:-EMPTY}" in

				"nixos" )

					nix flake update || {
						writeLog "ERROR" "Failed to update Nix flake"
						popd > /dev/null || return 1
						return 1
					}

				;;

				* )

					nix flake update || {
						writeLog "ERROR" "Failed to update Nix flake"
						popd > /dev/null || return 1
						return 1
					}

				;;

			esac

		;;

		"garbage-collect" )

			case "${OS_NAME:-EMPTY}" in

				"nixos" )

					nix-collect-garbage --delete-older-than 1d || {
						writeLog "ERROR" "Failed to collect Nix garbage"
						popd > /dev/null || return 1
						return 1
					}

				;;

				* )

					nix-collect-garbage --delete-older-than 1d || {
						writeLog "ERROR" "Failed to collect Nix garbage"
						popd > /dev/null || return 1
						return 1
					}

				;;

			esac
			

		;;

		* )

			writeLog "ERROR" "Invalid action: ${ACTION:-NONE}"
			return 1

		;;

	esac
	
	popd > /dev/null || {
		writeLog "ERROR" "Failed to pop the folder stack"
		return 1
	}

	return 0

}
