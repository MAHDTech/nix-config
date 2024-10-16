#!/usr/bin/env bash

#########################
# Name: debian.sh
# Description: Configures a Debian install for Nix.
#########################

set -euao pipefail

export LINUX_USER="${USER}"

INIT_SYSTEM=$(ps --no-headers -o comm 1)

export NIXPKGS_ALLOW_UNFREE=1

# If this is WSL, we need to give-in and enable systemd :(
case "${OS_LAYER^^}" in

"WSL")

	# Systemd or Init
	if grep -i init <<<"${INIT_SYSTEM:-unknown}"; then

		# Need to enable systemd :(
		sudo tee "/etc/wsl.conf" >/dev/null <<-EOF
			# WSL Configuration
			# Reference: https://learn.microsoft.com/en-gb/windows/wsl/wsl-config#wslconf

			[boot]
			systemd = true

			[automount]
			enabled = true
			mountFsTab = true
			root = "/mnt"
			options = "metadata,case=off"

			[network]
			generateHosts = true
			generateResolvConf = true
			#hostname = ""

			[interop]
			enabled = true
			appendWindowsPath = true

			[user]
			default = "mahdtech"

		EOF

		writeLog "INFO" "Systemd has now been enabled, run wsl --shutdown and then restart before running this script again."

		exit 0

	elif grep -i systemd <<<"${INIT_SYSTEM:-unknown}"; then

		writeLog "INFO" "Systemd is already running"

		writeLog "INFO" "Enabling linger for $LINUX_USER"
		sudo loginctl enable-linger "$LINUX_USER"

	fi

	;;

*)

	writeLog "INFO" "Not WSL, skipping configuration"

	;;

esac

# Nix installed locally
if [[ ${INSTALL_NIX_ON_DEBIAN:-FALSE} == "TRUE" ]]; then

	# Make sure the Nix bin dirs are in the PATH for this shell.
	export PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"
	export NIXPKGS_ALLOW_UNFREE=1

	if type nix 1>/dev/null 2>&1; then

		writeLog "INFO" "Nix is already installed"

	else

		writeLog "INFO" "Installing Nix dependencies"

		sudo apt install --yes \
			dbus \
			dbus-user-session \
			dconf-service \
			xz-utils || {
			writeLog "ERROR" "Failed to install dependant debs!"
			exit 1
		}

		writeLog "INFO" "Installing Nix"

		curl -sf -L https://nixos.org/nix/install -o /tmp/nix-install.sh || {
			writeLog "ERROR" "Failed to download Nix installer."
			exit 1
		}

		chmod +x /tmp/nix-install.sh
		sudo /tmp/nix-install.sh \
			--daemon \
			--yes ||
			{
				writeLog "ERROR" "Failed to install Nix!"
				exit 1
			}

		rm -f /tmp/install.nix

	fi

	writeLog "INFO" "Enabling Nix flakes"

	mkdir --parents "${HOME}/.config/nix" || {
		writeLog "ERROR" "Failed to create Nix user config directory"
		exit 2
	}

	cat <<-EOF >"${HOME}/.config/nix/nix.conf"
		# Nix CLI configuration for user $LINUX_USER
		experimental-features = nix-command flakes
	EOF

	writeLog "INFO" "Configuring Nix daemon"

	sudo tee "/etc/nix/nix.conf" >/dev/null <<-EOF
		# Nix daemon configuration

		allowed-users = @nix-users

		auto-optimise-store = true

		allow-dirty = true

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

		trusted-users = root @sudo @wheel @nix-users

		experimental-features = nix-command flakes
	EOF

	writeLog "INFO" "Restarting Nix daemon"

	sudo systemctl restart nix-daemon || {
		writeLog "ERROR" "Failed to restart the Nix daemon"
		exit 3
	}
	sleep 10

	writeLog "INFO" "Bootstrap Home Manager user configuration for $LINUX_USER"

	rm -f "$HOME/.profile" || true
	rm -f "$HOME/.bashrc" || true
	rm -f "$HOME/.sommelierrc" || true
	rm -rf "$HOME/.local/state/nix/profiles/home-manager"* || true
	rm -rf "$HOME/.local/state/home-manager/gcroots/current-home" || true

	sudo groupadd --force nix-users || {
		writeLog "ERROR" "Failed to create a nix-users group"
		exit 7
	}

	sudo usermod --append --groups nix-users "${LINUX_USER}" || {
		writeLog "ERROR" "Failed to add user ${LINUX_USER} to nix-users group!"
		exit 8
	}

	sudo mkdir --parents --mode 0755 /nix/var/nix/{profiles,gcroots}/per-user/"${LINUX_USER}" || {
		writeLog "ERROR" "Failed to create required directories for $LINUX_USER"
		exit 10
	}

	sudo mkdir --parents --mode 0755 /nix/var/nix/{profiles,gcroots}/per-user/"$(id -u)" || {
		writeLog "ERROR" "Failed to create required directories for $(id -u)"
		exit 11
	}

	sudo ln -srf /nix/var/nix/profiles/per-user/"$(id -u)" /nix/var/nix/profiles/per-user/"$(id -un)" || {
		writeLog "ERROR" "Failed to create required symlink from $(id -u) to $(id -un)"
		exit 14
	}

	sudo chown -R "root:nix-users" "/nix" || {
		writeLog "ERROR" "Failed to change ownership of /nix"
		exit 15
	}

	sudo chown -R "${LINUX_USER}:${LINUX_USER}" /nix/var/nix/{profiles,gcroots}/per-user/"${LINUX_USER}" || {
		writeLog "ERROR" "Failed to change ownership of /nix/var/nix/{profiles,gcroots}/per-user/${LINUX_USER}"
		exit 16
	}

	sudo chown -R "${LINUX_USER}:${LINUX_USER}" /nix/var/nix/{profiles,gcroots}/per-user/"$(id -u)" || {
		writeLog "ERROR" "Failed to change ownership of /nix/var/nix/{profiles,gcroots}/per-user/$(id -u)"
		exit 17
	}

	# HACK: https://github.com/NixOS/nix/issues/10421
	sudo chown -R "${LINUX_USER}:${LINUX_USER}" /nix || {
		writeLog "ERROR" "Failed to change ownership of /nix"
		exit 18
	}

	NIX_BIN="/nix/var/nix/profiles/default/bin/nix"

	$NIX_BIN build --impure --no-link ".#homeConfigurations.${LINUX_USER}.activationPackage" || {
		writeLog "ERROR" "Failed to build Home Manager config for user ${LINUX_USER}"
		exit 15
	}

	"$($NIX_BIN path-info --impure ".#homeConfigurations.${LINUX_USER}.activationPackage")"/activate || {
		writeLog "ERROR" "Failed to activate Home Manager"
		exit 16
	}

	# So nix ignores any flake.nix in the current dir if the location is external.
	if [[ ${FLAKE_LOCATION:-.} != "." ]]; then
		pushd "$(mktemp -d)" || {
			writeLog "ERROR" "Failed to push to temp dir!"
			exit 1
		}
	fi

	writeLog "INFO" "Building the Home Manager environment for user $LINUX_USER from flake ${FLAKE_LOCATION:-.}"

	home-manager build --impure --flake "${FLAKE_LOCATION:-.}#$LINUX_USER" || {
		writeLog "ERROR" "Failed to build Home Manger config for user $LINUX_USER"
		exit 15
	}

	writeLog "INFO" "Switching into the Home Manager environment for user $LINUX_USER from flake ${FLAKE_LOCATION:-.}"

	home-manager switch --impure --flake "${FLAKE_LOCATION:-.}#$LINUX_USER" || {
		writeLog "ERROR" "Failed to switch into Home Manger config for user $LINUX_USER"
		exit 16
	}

	#writeLog "INFO" "Installing cachix"

	#nix profile install --accept-flake-config nixpkgs#cachix || {
	#	writeLog "ERROR" "Failed to install cachix"
	#	exit 17
	#}

	#writeLog "INFO" "Installing devenv"

	#nix profile install --accept-flake-config nixpkgs#devenv || {
	#	writeLog "ERROR" "Failed to install devenv"
	#	exit 18
	#}

	popd 1>/dev/null 2>&1 || true

else

	writeLog "INFO" "Skipping Nix installation on Debian as \$INSTALL_NIX_ON_DEBIAN is ${INSTALL_NIX_ON_DEBIAN}"

fi

#########################
# Setup Debian
#########################

writeLog "INFO" "Updating debian release to ${DEBIAN_VERSION_CODENAME}"

for CODENAME in "${DEBIAN_VERSION_CODENAMES[@]}"; do

	writeLog "INFO" "Updating apt repos from ${CODENAME} to ${DEBIAN_VERSION_CODENAME}"

	sudo sed -i "s/${CODENAME}/${DEBIAN_VERSION_CODENAME}/g" /etc/apt/sources.list || {
		writeLog "ERROR" "Failed to update /etc/apt/sources.list"
		exit 31
	}

	sudo sed -i "s/${CODENAME}/${DEBIAN_VERSION_CODENAME}/g" /etc/apt/sources.list.d/*.list || {
		writeLog "WARN" "Failed to update /etc/apt/sources.list.d/*"
	}

done

sudo apt update || {
	writeLog "ERROR" "Failed to update apt repo metadata"
	exit 33
}

sudo apt upgrade --yes --without-new-pkgs || {
	writeLog "ERROR" "Failed to perform minimal system upgrade to ${DEBIAN_VERSION_CODENAME}"
	exit 34
}

sudo apt full-upgrade --yes || {
	writeLog "ERROR" "Failed to perform full system upgrade to ${DEBIAN_VERSION_CODENAME}"
	exit 35
}

#########################
# Setup Docker
#########################

sudo apt update || {
	writeLog "ERROR" "Failed to update apt repo metadata"
	exit 20
}

sudo apt install --yes \
	curl \
	wget \
	gpg \
	apt-transport-https \
	ca-certificates \
	lsb-release || {
	writeLog "ERROR" "Failed to install dependant packages"
	exit 21
}

sudo mkdir --parents --mode 0755 /etc/apt/keyrings || {
	writeLog "ERROR" "Failed to create keyrings directory"
	exit 22
}

wget -qO- https://download.docker.com/linux/debian/gpg | gpg --dearmor -o docker.gpg

sudo install -D -o root -g root -m 644 docker.gpg /etc/apt/keyrings/docker.gpg

rm -f docker.gpg

sudo tee "/etc/apt/sources.list.d/docker.list" >/dev/null <<-EOF
	deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable
EOF

sudo apt update || {
	writeLog "ERROR" "Failed to update apt repo metadata"
	exit 20
}

sudo apt install --yes \
	docker-ce \
	docker-ce-cli \
	docker-buildx-plugin \
	docker-compose-plugin \
	containerd.io || {
	writeLog "ERROR" "Failed to install dependant debs!"
	exit 21
}

sudo usermod --append --groups docker "$LINUX_USER" || {
	writeLog "ERROR" "Failed to add user $LINUX_USER to docker group!"
	exit 23
}

#########################
# Setup VSCode
#########################

if [[ ${INSTALL_VSCODE^^} == "TRUE" ]]; then

	# On ChromeOS, install VSCode
	# On WSL, use VSCode on Windows

	case "${OS_LAYER^^}" in

	"CROSTINI")

		writeLog "INFO" "Installing VSCode in Debian"

		wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o packages.microsoft.gpg

		sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

		sudo tee "/etc/apt/sources.list.d/vscode.list" >/dev/null <<-EOF
			deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
		EOF

		rm -f packages.microsoft.gpg docker.gpg

		sudo apt update || {
			writeLog "ERROR" "Failed to update apt repo metadata"
			exit 20
		}

		sudo apt install --yes \
			code || {
			writeLog "ERROR" "Failed to install dependant debs!"
			exit 21
		}

		;;

	"WSL")

		writeLog "INFO" "Skipping VSCode install in favour of using VSCode from Windows"

		;;

	*)

		writeLog "INFO" "Unknown OS Layer ${OS_LAYER}"

		;;

	esac

fi

#########################
# Testing
#########################

sudo systemctl enable --now docker || {

	writeLog "ERROR" "Failed to start Docker service"
	exit 250

}

sudo docker run \
	--name hello-world \
	--rm \
	docker.io/hello-world || {
	writeLog "ERROR" "Failed to test Docker!"
	exit 249
}

#########################
# Shell
#########################

sudo usermod \
	--shell "/home/${LINUX_USER}/.nix-profile/bin/bash" \
	"${LINUX_USER}" || {
	writeLog "ERROR" "Failed to change shell for ${LINUX_USER}"
	exit 1
}

#########################
# Cleanup
#########################

sudo apt remove --yes \
	curl \
	git \
	wget || {
	writeLog "ERROR" "Failed to remove unnecessary packages"
	exit 250
}

sudo apt autoremove --yes || {
	writeLog "ERROR" "Failed to run apt autoremove"
	exit 251
}

sudo apt autoclean --yes || {
	writeLog "ERROR" "Failed to run apt autoclean"
	exit 252
}

#########################
# Finished
#########################
