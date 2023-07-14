#!/usr/bin/env bash

#########################
# Name: debian.sh
# Description: Configures a Debian install for Nix.
#########################

set -e
set -u
set -o pipefail

if type nix 1> /dev/null 2>&1;
then
	writeLog "INFO" "Nix is already installed"
else

	writeLog "INFO" "Installing Nix"

	sh <(curl -L https://nixos.org/nix/install) --daemon || {
		writeLog "ERROR" "Failed to install Nix"
		exit 1
	}
		fi

writeLog "INFO" "Enabling Nix flakes"

mkdir --parents "${HOME}/.config/nix" || {
	writeLog "ERROR" "Failed to create Nix user config directory"
	exit 2
}

cat << EOF > "${HOME}/.config/nix/nix.conf"
# Nix CLI configuration for user $USER
experimental-features = nix-command flakes
EOF

sudo tee "/etc/nix/nix.conf" > /dev/null << EOF
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

trusted-users = root @sudo $USER 

experimental-features = nix-command flakes
EOF

writeLog "INFO" "Restarting Nix daemon" 

sudo systemctl restart nix-daemon || {
	writeLog "ERROR" "Failed to restart the Nix daemon"
	exit 3
}

# The Nix bin is not available in the current shell
export PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"

if [[ ! "${CACHIX_AUTH_TOKEN:-EMPTY}" == "EMPTY" ]];
then
	writeLog "INFO" "Install Cachix"
	nix-env -iA cachix -f https://cachix.org/api/v1/install || {
		writeLog "ERROR" "Failed to install Cachix"
		exit 4
	}

	cachix authtoken "${CACHIX_AUTH_TOKEN}" || {
		writeLog "ERROR" "Failed to set Cachix auth token"
		exit 5
	}

	if [[ ! "${CACHIX_CACHE_NAME:-EMPTY}" == "EMPTY" ]];
	then

		cachix use "${CACHIX_CACHE_NAME}" || {
			writeLog "ERROR" "Failed to run 'cachix use ${CACHIX_CACHE_NAME}"
			exit 6
		}
	fi

fi

writeLog "INFO" "Bootstrap Home Manager user configuration for $USER"

rm -f "$HOME/.profile" || true
rm -f "$HOME/.bashrc" || true

nix build --impure --no-link ".#homeConfigurations.${USER}.activationPackage" || {
	writeLog "ERROR" "Failed to build Home Manager config for user ${USER}"
	exit 8
}

sudo groupadd --force nix-users || {
	writeLog "ERROR" "Failed to create a nix-users group"
	exit 9
}

sudo mkdir --parents --mode 0755 /nix/var/nix/{profiles,gcroots}/per-user/${USER} || {
	writeLog "ERROR" "Failed to create required directories for $USER"
	exit 10
}
sudo mkdir --parents --mode 0755 /nix/var/nix/{profiles,gcroots}/per-user/$(id -u) || {
	writeLog "ERROR" "Failed to create required directories for $(id -u)"
	exit 11
}

sudo chown -R "${USER}:nix-users" /nix/var/nix/{profiles,gcroots}/per-user/${USER} || {
	writeLog "ERROR" "Failed to chown required directories for $USER"
	exit 12
}

sudo chown -R "${USER}:nix-users" /nix/var/nix/{profiles,gcroots}/per-user/$(id -u) || {
	writeLog "ERROR" "Failed to chown required directories for $(id -u)"
	exit 13
}

sudo ln -srf /nix/var/nix/profiles/per-user/$(id -u) /nix/var/nix/profiles/per-user/$(id -un) || {
	writeLog "ERROR" "Failed to create required symlink from $(id -u) to $(id -un)"
	exit 14
}

"$(nix path-info --impure ".#homeConfigurations.${USER}.activationPackage")"/activate || {
	writeLog "ERROR" "Failed to activate Home Manager"
	exit 15
}

writeLog "INFO" "Building the Home Manager environment for user $USER"

home-manager build --impure --flake ".#$USER" || {
	writeLog "ERROR" "Failed to build Home Manger config for user $USER"
	exit 15
}

writeLog "INFO" "Switching into the Home Manager environment for user $USER"

home-manager switch --impure --flake ".#$USER" || {
	writeLog "ERROR" "Failed to switch into Home Manger config for user $USER"
	exit 16
}

