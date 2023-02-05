#!/usr/bin/env bash

##################################################
# Name: nix
# Description: Assorted Nix related functions
##################################################

function home-manager-exec() {

	# A wrapper function for executing home-manager commands as a I really can't
	# stand having a "result" folder in every single fucking directory I chose
	# to run 'home-manager build' from.

	local HOME_MANAGER_PARAMS="$*"

	writeLog "INFO" "Executing Nix Home Manager"

	pushd "${HOME}" > /dev/null || {
		writeLog "ERROR" "Failed to pushd to \$HOME"
		return 1
	};

	# shellcheck disable=2086
	home-manager build ${HOME_MANAGER_PARAMS} || {
		writeLog "ERROR" "Failed to perform Nix Home Manager update (Dry Run)"
		popd || return 1
		return 1
	};

	# shellcheck disable=2086
	home-manager switch ${HOME_MANAGER_PARAMS} || {
		writeLog "ERROR" "Failed to perform Nix Home Manager update"
		popd || return 1
		return 1
	};

	popd > /dev/null || {
		writeLog "ERROR" "Failed to popd from \$HOME"
		return 1
	};

	# Show the news to keep on top of breaking changes.
	home-manager news

	return 0

}

function nix-uninstall() {

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

