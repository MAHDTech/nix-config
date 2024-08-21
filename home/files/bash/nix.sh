#!/usr/bin/env bash

##################################################
# Name: nix
# Description: Assorted Nix related functions
##################################################

function nix-upgrade-daemon() {

	if [[ ${DOTFILES_CONFIG:-EMPTY} == "EMPTY" ]]; then
		"Environment variable DOTFILES_CONFIG is empty"
		return 1
	fi

	pushd "${DOTFILES_CONFIG}" || {
		writeLog "ERROR" "Failed to push into dotfiles directory"
		return 1
	}

	if type nix 1>/dev/null 2>&1; then

		nix flake update --flake . || {
			writeLog "ERROR" "Failed to update nix flake"
			return 1
		}

		nix-channel --update || {
			writeLog "ERROR" "Failed to update nix channels"
			return 1
		}

		#nix profile upgrade cachix || {
		#	writeLog "ERROR" "Failed to upgrade cachix profile"
		#	return 1
		#}

		#nix profile upgrade devenv || {
		#	writeLog "ERROR" "Failed to upgrade devenv profile"
		#	return 1
		#}

		writeLog "INFO" "Upgrading Nix Daemon"

	else

		writeLog "INFO" "Installing Nix Daemon"

	fi

	writeLog "INFO" "Elevating permissions"
	sudo --validate || {
		writeLog "ERROR" "Failed to elevate permissions"
		return 1
	}

	# If there is a backup bashrc file, restore it before upgrading.
	if [[ -f /etc/bashrc.backup-before-nix ]]; then
		writeLog "WARN" "Restoring /etc/bash.bashrc"
		sudo rm -f /etc/bashrc || true
		sudo mv /etc/bashrc.backup-before-nix /etc/bashrc || {
			writeLog "ERROR" "Failed to restore /etc/bashrc"
			return 1
		}
	fi

	# If there is a backup bash.bashrc file, restore it before upgrading.
	if [[ -f /etc/bash.bashrc.backup-before-nix ]]; then
		writeLog "WARN" "Restoring /etc/bash.bashrc"
		sudo rm -f /etc/bash.bashrc || true
		sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc || {
			writeLog "ERROR" "Failed to restore /etc/bash.bashrc"
			return 1
		}
	fi

	# If there is a backup profile/nix.sh file, restore it before upgrading.
	if [[ -f /etc/profile.d/nix.sh.backup-before-nix ]]; then
		writeLog "WARN" "Restoring /etc/profile.d/nix.sh"
		sudo rm -f /etc/profile.d/nix.sh || true
		sudo mv /etc/profile.d/nix.sh.backup-before-nix /etc/profile.d/nix.sh || {
			writeLog "ERROR" "Failed to restore /etc/profile.d/nix.sh"
			return 1
		}
	fi

	# If there is a backup /etc/zshrc file, restore it before upgrading.
	if [[ -f /etc/zshrc.backup-before-nix ]]; then
		writeLog "WARN" "Restoring /etc/zshrc"
		sudo rm -f /etc/zshrc || true
		sudo mv /etc/zshrc.backup-before-nix /etc/zshrc || {
			writeLog "ERROR" "Failed to restore /etc/zshrc"
			return 1
		}
	fi

	sudo rm -f /tmp/nix-install.sh || true
	curl -sf -L https://nixos.org/nix/install -o /tmp/nix-install.sh || {
		writeLog "ERROR" "Failed to download Nix installer."
		return 1
	}

	chmod +x /tmp/nix-install.sh
	sudo /tmp/nix-install.sh \
		--daemon \
		--no-modify-profile \
		--yes ||
		{
			writeLog "ERROR" "Failed to install Nix!"
			return 1
		}

	sudo tee "/etc/nix/nix.conf" >/dev/null <<-EOF
		# Nix daemon configuration

		allowed-users = *

		auto-optimise-store = true

		build-users-group = nixbld
		builders =
		cores = 0
		extra-sandbox-paths =
		sandbox-build-dir = /nix/sandbox/build
		max-jobs = auto
		require-sigs = true
		sandbox = true
		sandbox-fallback = false

		min-free = 10737418240

		keep-outputs = true
		keep-derivations = true

		trusted-users = root @sudo ${USER:-}

		experimental-features = nix-command flakes
	EOF

	sudo systemctl daemon-reload || {
		writeLog "ERROR" "Failed to reload systemctl daemon"
		return 1
	}

	sudo systemctl restart nix-daemon || {
		writeLog "ERROR" "Failed to restart nix-daemon"
		return 1
	}

	popd || {
		writeLog "ERROR" "Failed to pop out of dotfiles directory"
		return 1
	}

	return 0

}

function nix-uninstall() {

	local NIX_STORE_HOME="/nix"
	local NIX_STORE_CONFIG="/etc/nix"
	local NIX_PROFILE_SCRIPT="${HOME}/.nix-profile/etx/profile.d/nix.sh"

	# Is there an existing /nix dir?
	if [[ -d ${NIX_STORE_HOME} ]]; then

		writeLog "INFO" "Uninstalling Nix"

		sudo rm -rf "${HOME}/"{.nix-channels,.nix-defexpr,.nix-profile,.config/nixpkgs} || {
			writeLog "WARNING" "Failed to remove all Nix directories in HOME"
		}

		sudo rm -rf /root/{.nix-channels,.nix-defexpr,.nix-profile,.config/nixpkgs} || {
			writeLog "WARNING" "Failed to remove all Nix directories in root"
		}

		sudo rm -f /etc/profile.d/nix.sh* || {
			writeLog "ERROR" "Failed to remove nix.sh profile"
		}

		sudo rm -rf "${NIX_STORE_HOME}" || {
			writeLog "ERROR" "Failed to remove Nix Store home"
		}

		sudo rm -rf "${NIX_STORE_CONFIG}" || {
			writeLog "ERROR" "Failed to remove Nix Store config"
		}

		sudo rm -f "${NIX_PROFILE_SCRIPT}" || {
			writeLog "ERROR" "Failed to remove Nix Profile script"
		}

		# If there is a backup bashrc file, restore it before upgrading.
		if [[ -f /etc/bashrc.backup-before-nix ]]; then
			writeLog "WARN" "Restoring /etc/bash.bashrc"
			sudo rm -f /etc/bashrc || true
			sudo mv /etc/bashrc.backup-before-nix /etc/bashrc || {
				writeLog "ERROR" "Failed to restore /etc/bashrc"
				return 1
			}
		fi

		# If there is a backup bash.bashrc file, restore it before upgrading.
		if [[ -f /etc/bash.bashrc.backup-before-nix ]]; then
			writeLog "WARN" "Restoring /etc/bash.bashrc"
			sudo rm -f /etc/bash.bashrc || true
			sudo mv /etc/bash.bashrc.backup-before-nix /etc/bash.bashrc || {
				writeLog "ERROR" "Failed to restore /etc/bash.bashrc"
				return 1
			}
		fi

		# If there is a backup profile/nix.sh file, restore it before upgrading.
		if [[ -f /etc/profile.d/nix.sh.backup-before-nix ]]; then
			writeLog "WARN" "Restoring /etc/profile.d/nix.sh"
			sudo rm -f /etc/profile.d/nix.sh || true
			sudo mv /etc/profile.d/nix.sh.backup-before-nix /etc/profile.d/nix.sh || {
				writeLog "ERROR" "Failed to restore /etc/profile.d/nix.sh"
			}
		fi

		# If there is a backup /etc/zshrc file, restore it before upgrading.
		if [[ -f /etc/zshrc.backup-before-nix ]]; then
			writeLog "WARN" "Restoring /etc/zshrc"
			sudo rm -f /etc/zshrc || true
			sudo mv /etc/zshrc.backup-before-nix /etc/zshrc || {
				writeLog "ERROR" "Failed to restore /etc/zshrc"
			}
		fi

	else

		writeLog "WARN" "Nix is not installed, skipping uninstall"

	fi

	writeLog "INFO" "Finished Nix uninstall"
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

	"nixos")

		nixos-rebuild \
			"${ACTION}" \
			--use-remote-sudo \
			--upgrade-all \
			--refresh \
			--impure \
			--flake "${FLAKE_LOCATION}#" \
			"${EXTRA_ARGS[@]}" || {

			writeLog "ERROR" "Failed to perform NixOS ${ACTION,,}"
			popd >/dev/null 2>&1 || true
			return 1

		}

		;;

	*)

		home-manager \
			"${ACTION}" \
			--impure \
			--flake "${FLAKE_LOCATION}" \
			"${EXTRA_ARGS[@]}" || {

			writeLog "ERROR" "Failed to perform Nix Home Manager ${ACTION,,}"
			popd >/dev/null 2>&1 || true
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

	local DOTFILES_CONFIG="${DOTFILES_CONFIG:=$HOME/dotfiles}"

	local FLAKE_LOCATION
	local FLAKE_REMOTE="github:MAHDTech/nix-config"
	local FLAKE_LOCAL="."
	local FLAKE_HOME_MANAGER
	#FLAKE_HOME_MANAGER="$(printf '%s\n' "$(whoami)"@"$(hostname)")"
	FLAKE_HOME_MANAGER="${USER%%@*}"

	local EXECUTE="FALSE"

	local VALID_ACTIONS=(

		# Common
		"cd"
		"dir"
		"info"
		"check"
		"build"
		"test"
		"switch"
		"update"
		"garbage-collect"

		# NixOS
		"boot"

	)

	# Check if the action is valid before continuing.
	for VALID_ACTION in "${VALID_ACTIONS[@]}"; do

		if [[ $ACTION == "$VALID_ACTION" ]]; then
			writeLog "DEBUG" "The action ${ACTION} is valid."
			EXECUTE="TRUE"
			break
		fi

	done

	# Return if the action is invalid.
	if [[ ${EXECUTE} == "FALSE" ]]; then

		writeLog "ERROR" "Invalid action: ${ACTION:-NONE}"
		return 1

	fi

	# Change into the dotfiles config directory.
	if [[ ${FLAKE_LOCATION_FORCED:-NONE} != "NONE" ]]; then
		writeLog "WARN" "Using FORCED dotfiles as flake location is set to ${FLAKE_LOCATION_FORCED}"
		FLAKE_LOCATION="${FLAKE_LOCATION_FORCED}"

	elif [[ -d ${DOTFILES_CONFIG} ]]; then

		pushd "${DOTFILES_CONFIG}" >/dev/null || {
			writeLog "Failed to change into ${DOTFILES_CONFIG}"
			return 1
		}

		# HACK: allow dirty
		git add --all || true

		writeLog "WARN" "Using LOCAL dotfiles as the config directory is present ${DOTFILES_CONFIG}"
		FLAKE_LOCATION="${FLAKE_LOCAL}"

	else

		writeLog "WARN" "Using REMOTE dotfiles as the config directory is not present ${DOTFILES_CONFIG}"
		FLAKE_LOCATION="${FLAKE_REMOTE}"

	fi

	case "${OS_NAME:-EMPTY}" in

	"nixos")

		writeLog "DEBUG" "Flake location set to ${FLAKE_LOCATION}"

		;;

	*)

		FLAKE_LOCATION="${FLAKE_LOCATION}#${FLAKE_HOME_MANAGER}"
		writeLog "DEBUG" "Flake location set to ${FLAKE_LOCATION}"

		;;

	esac

	writeLog "INFO" "Executing ${ACTION} on Nix Flake ${FLAKE_LOCATION}"

	case "${ACTION}" in

	cd | dir | pushd)

		popd >/dev/null 2>&1 || return 1

		cd "${DOTFILES_CONFIG}" >/dev/null || {
			writeLog "ERROR" "Failed to change into ${DOTFILES_CONFIG}"
			return 1
		}

		;;

	info)

		nix flake info || {
			writeLog "ERROR" "Failed to display flake info"
			return 1
		}

		;;

	check)

		nix flake check \
			--no-build \
			--keep-going \
			--impure \
			"${EXTRA_ARGS[@]}" || {
			writeLog "WARN" "Failed flake check!"
			return 1
		}

		nix run nixpkgs#statix -- check || {
			writeLog "WARN" "Failed to run statix!"
			return 1
		}

		;;

	build)

		_dotfiles_actions "build" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
			writeLog "ERROR" "Failed to build dotfiles"
			return 1
		}

		;;

	test)

		_dotfiles_actions "test" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
			writeLog "ERROR" "Failed to test dotfiles"
			return 1
		}

		;;

	boot)

		if [[ ${OS_NAME} != "nixos" ]]; then
			writeLog "ERROR" "Switching over on boot is only supported on NixOS"
			return 1
		fi

		_dotfiles_actions "boot" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
			writeLog "ERROR" "Failed to switch dotfiles"
			return 1
		}

		;;

	switch)

		_dotfiles_actions "switch" "${FLAKE_LOCATION}" "${EXTRA_ARGS[@]}" || {
			writeLog "ERROR" "Failed to switch dotfiles"
			return 1
		}

		;;

	update)

		case "${OS_NAME:-EMPTY}" in

		"nixos")

			nix-channel --update || {
				writeLog "ERROR" "Failed to update Nix channel"
				popd >/dev/null 2>&1 || true
				return 1
			}

			nix flake update || {
				writeLog "ERROR" "Failed to update Nix flake"
				popd >/dev/null 2>&1 || true
				return 1
			}

			;;

		*)

			nix-channel --update || {
				writeLog "ERROR" "Failed to update Nix channel"
				popd >/dev/null 2>&1 || true
				return 1
			}

			nix flake update || {
				writeLog "ERROR" "Failed to update Nix flake"
				popd >/dev/null 2>&1 || true
				return 1
			}

			;;

		esac

		;;

	garbage-collect)

		case "${OS_NAME:-EMPTY}" in

		"nixos")

			nix-collect-garbage --delete-older-than 7d || {
				writeLog "ERROR" "Failed to collect Nix garbage"
				popd >/dev/null 2>&1 || true
				return 1
			}

			;;

		*)

			nix-collect-garbage --delete-older-than 7d || {
				writeLog "ERROR" "Failed to collect Nix garbage"
				popd >/dev/null 2>&1 || true
				return 1
			}

			;;

		esac

		;;

	*)

		writeLog "ERROR" "Invalid action: ${ACTION:-NONE}"
		return 1

		;;

	esac

	popd >/dev/null 2>&1 || {
		writeLog "ERROR" "Failed to pop the folder stack"
		return 1
	}

	return 0

}

function dotfiles_all_the_things() {

	nix-channel --update || {
		writeLog "ERROR" "Failed to update nix channels"
		return 1
	}

	dotfiles update || {
		writeLog "ERROR" "Failed to update dotfiles"
		return 1
	}

	dotfiles check || {
		writeLog "ERROR" "Failed to check dotfiles"
		return 1
	}

	dotfiles build || {
		writeLog "ERROR" "Failed to build dotfiles"
		return 1
	}

	# NixOS
	if [[ ${OS_NAME:-UNKNOWN} == "nixos" ]]; then

		dotfiles boot || {
			writeLog "ERROR" "Failed to boot dotfiles"
			return 1
		}

	# Debian
	elif [[ ${OS_NAME:-UNKNOWN} == "debian" ]]; then

		dotfiles switch || {
			writeLog "ERROR" "Failed to switch dotfiles"
			return 1
		}

	else

		writeLog "ERROR" "Unsupported OS ${OS_NAME:-UNKNOWN}"
		return 1

	fi

	dotfiles garbage-collect || {
		writeLog "ERROR" "Failed to collect garbage"
		return 1
	}

	return 0

}
