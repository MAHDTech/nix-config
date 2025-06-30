#!/bin/bash

clear

set -euo pipefail

export DEBUG=${DEBUG:-FALSE}

if [[ ${DEBUG^^} == "TRUE" ]]; then
	set -x
fi

# Pulsar project
PULSAR_HOME="${HOME}/Games/PulsarGame"
PULSAR_BINARY_LINUX="${PULSAR_HOME}/Linux/Pulsar/Binaries/Linux/Pulsar-Linux-Shipping"
PULSAR_BINARY_WINDOWS="${PULSAR_HOME}/Windows/Pulsar/Binaries/Win64/Pulsar-Win64-Shipping.exe"

# Global variable to track which binary we're using
PULSAR_BINARY=""

# 1. Common environment setup
setup_env() {
	export SDL_VIDEODRIVER=wayland
	export VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
	export WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
	export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
	export XDG_SESSION_TYPE=wayland
	export VK_LAYER_ENABLE_VALIDATION=0

	# Intel ARC GPU
	export LIBVA_DRIVER_NAME="iHD"
	export VDPAU_DRIVER="va_gl"
	export LIBVA_DRIVER_NAME="iHD"
	export __GLX_VENDOR_LIBRARY_NAME="mesa"
	# Vulkan ICD (Installable Client Driver) for Intel ARC GPU
	VK_ICD_FILENAMES="$(nix-build --no-out-link "<nixpkgs>" -A mesa)/share/vulkan/icd.d/intel_icd.x86_64.json"
	export VK_ICD_FILENAMES

}

# 2. Common package setup
setup_packages() {
	# List of required Nix packages
	PACKAGES=(
		# Common Linux packages
		SDL2
		alsa-lib
		at-spi2-atk
		at-spi2-core
		atk
		cairo
		curl
		dbus.lib
		expat
		glib.out
		libdrm
		libsecret
		libxkbcommon
		mesa
		nspr
		nss
		openssl
		pango.out
		vulkan-loader
		vulkan-tools
		vulkan-validation-layers
		wayland
		wayland-protocols
		xorg.libxcb
		# Intel ARC GPU
		intel-compute-runtime
		intel-media-driver
		# Proton support for Windows binaries
		proton-caller
		proton-ge-bin
		dxvk
		# Extra gaming utilities
		mangohud
		gamemode
	)
}

# 3. Common library path setup
setup_library_paths() {
	echo "Preparing LD Library PATH inside nix-shell..."

	# Library-to-package mapping for efficient lookup
	declare -A lib_to_pkg=(
		["libasound.so.2"]="alsa-lib"
		["libatk-1.0.so.0"]="atk"
		["libatk-bridge-2.0.so.0"]="at-spi2-core"
		["libatspi.so.0"]="at-spi2-core"
		["libcairo.so.2"]="cairo"
		["libcrypto.so"]="openssl"
		["libcurl.so"]="curl"
		["libdbus-1.so.3"]="dbus.lib"
		["libdrm.so.2"]="libdrm"
		["libexpat.so.1"]="expat"
		["libgbm.so.1"]="mesa"
		["libgio-2.0.so.0"]="glib.out"
		["libglib-2.0.so.0"]="glib.out"
		["libgobject-2.0.so.0"]="glib.out"
		["libnspr4.so"]="nspr"
		["libnss3.so"]="nss"
		["libnssutil3.so"]="nss"
		["libpango-1.0.so.0"]="pango.out"
		["libsecret-1.so.0"]="libsecret"
		["libsmime3.so"]="nss"
		["libssl.so"]="openssl"
		["libvulkan.so.1"]="vulkan-loader"
		["libwayland-client.so.0"]="wayland"
		["libxcb.so.1"]="xorg.libxcb"
		["libxkbcommon.so.0"]="libxkbcommon"
	)

	# List of required libraries
	LIBS=(
		libasound.so.2
		libatk-1.0.so.0
		libatk-bridge-2.0.so.0
		libatspi.so.0
		libcairo.so.2
		libdbus-1.so.3
		libdrm.so.2
		libexpat.so.1
		libgbm.so.1
		libgio-2.0.so.0
		libglib-2.0.so.0
		libgobject-2.0.so.0
		libnspr4.so
		libnss3.so
		libnssutil3.so
		libpango-1.0.so.0
		libsecret-1.so.0
		libsmime3.so
		libvulkan.so.1
		libwayland-client.so.0
		libxcb.so.1
		libxkbcommon.so.0
	)

	# Cache store paths for each package to avoid redundant nix-build calls
	declare -A store_paths
	for pkg in "${PACKAGES[@]}"; do
		store_paths["$pkg"]=$(nix-build --no-out-link "<nixpkgs>" -A "$pkg" 2>/dev/null || true)
	done

	# Build LD_LIBRARY_PATH by finding the exact library files
	LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
	for lib in "${LIBS[@]}"; do
		pkg="${lib_to_pkg[$lib]}"
		if [ -n "$pkg" ]; then
			store_path="${store_paths[$pkg]}"
			if [ -n "$store_path" ]; then
				# Search for the library file in the entire store path
				lib_path=$(find "$store_path" -name "$lib" 2>/dev/null | head -n 1)
				if [ -n "$lib_path" ]; then
					# Add the directory containing the library to LD_LIBRARY_PATH
					lib_dir=$(dirname "$lib_path")
					LIBRARY_PATH="$lib_dir:$LIBRARY_PATH"
					echo "Found $lib in $lib_dir"
				else
					echo "Warning: $lib not found in $pkg"
				fi
			else
				echo "Warning: Could not build store path for $pkg"
			fi
		else
			echo "Warning: No package mapping for $lib"
		fi
	done

	# Remove duplicates and trailing colon
	LIBRARY_PATH=$(echo "$LIBRARY_PATH" | tr ':' '\n' | sort -u | tr '\n' ':' | sed 's/:$//')
	export LIBRARY_PATH

	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "LIBRARY_PATH=$LIBRARY_PATH"
	fi
}

# 4a. Steam-run execution method
run_with_steam_run() {
	echo "Starting Pulsar with steam-run..."
	echo "Using FHS environment with enhanced library support..."

	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "Debug: Testing library resolution with steam-run"
		nix-shell -p "${PACKAGES[@]}" steam-run --run "${LAUNCH_OPTS[steam_run]} LD_LIBRARY_PATH='$LIBRARY_PATH' steam-run ldd '${PULSAR_BINARY}'"
	fi

	# Run the Linux binary with steam-run.
	nix-shell -p "${PACKAGES[@]}" steam-run \
		--verbose \
		--run "${LAUNCH_OPTS[steam_run]} LD_LIBRARY_PATH='$LIBRARY_PATH' steam-run '${PULSAR_BINARY}' Pulsar $*"
}

# 4b. Nix-shell execution method
run_with_nix_shell() {
	echo "Starting Pulsar with nix-shell..."
	echo "Using enhanced LD_LIBRARY_PATH management..."

	export LD_LIBRARY_PATH="$LIBRARY_PATH"

	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "Debug: Testing library resolution with nix-shell"
		nix-shell -p "${PACKAGES[@]}" --run "${LAUNCH_OPTS[nix_shell]} ldd ${PULSAR_BINARY}"
	fi

	nix-shell -p "${PACKAGES[@]}" \
		--verbose \
		--run "${LAUNCH_OPTS[nix_shell]} ${PULSAR_BINARY} Pulsar $*"
}

# 4c. Proton Caller execution method
run_with_proton_caller() {
	echo "Starting Pulsar with proton-caller..."

	local COMMON_DIR="$HOME/.local/share/proton-caller/common"
	mkdir -p "$COMMON_DIR"

	# Get the name and path of the Proton version from nixpkgs.
	local PROTON_NIX_PACKAGE="proton-ge-bin"

	# Get the full nix store path for the Proton package. This is the most compatible way.
	local PROTON_STORE_PATH_FULL
	PROTON_STORE_PATH_FULL=$(nix-build --no-out-link "<nixpkgs>" -A "$PROTON_NIX_PACKAGE")

	# Derive the version name from the store path.
	# e.g., /nix/store/...-proton-ge-bin-GE-Proton10-4 -> GE-Proton10-4
	local PROTON_VERSION_NAME
	PROTON_VERSION_NAME=$(basename "$PROTON_STORE_PATH_FULL" | sed 's/^[a-z0-9]*-//' | sed "s/^${PROTON_NIX_PACKAGE}-//")

	local PROTON_LINK_PATH="$COMMON_DIR/$PROTON_VERSION_NAME"

	# Symlink the nix-managed Proton into the proton-caller directory if it's not already there.
	if [ ! -L "$PROTON_LINK_PATH" ]; then
		echo "Proton version '$PROTON_VERSION_NAME' not found in proton-caller directory."
		echo "Creating symlink from nix store..."

		# The actual Proton distribution is in the 'dist' subdirectory.
		local PROTON_DIST_PATH="$PROTON_STORE_PATH_FULL/dist"

		ln -s "$PROTON_DIST_PATH" "$PROTON_LINK_PATH"
		echo "Symlink created at $PROTON_LINK_PATH"
	fi

	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "Debug: Windows binary: $PULSAR_BINARY"
		echo "Debug: Using Proton version: $PROTON_VERSION_NAME"
	fi

	# Run the Windows binary using the specific Proton version we just ensured exists.
	nix-shell -p "${PACKAGES[@]}" \
		--verbose \
		--run "${LAUNCH_OPTS[proton_caller]} proton-call -p '$PROTON_VERSION_NAME' -r '${PULSAR_BINARY}' Pulsar $*"
}

# 5. Launch-specific options
setup_launch_options() {
	declare -gA LAUNCH_OPTS
	# Options for steam-run: enable MangoHud
	LAUNCH_OPTS[steam_run]="mangohud"

	# Options for nix-shell: enable gamemode
	LAUNCH_OPTS[nix_shell]="gamemoderun"

	# Options for proton_caller: enable async DXVK for potential performance improvements
	LAUNCH_OPTS[proton_caller]="DXVK_ASYNC=1"
}

# Main execution
main() {
	# Check which binaries exist and build dynamic menu
	declare -a options=()
	declare -a commands=()

	LINUX_BINARY_EXISTS=false
	WINDOWS_BINARY_EXISTS=false

	if [[ -f $PULSAR_BINARY_LINUX ]]; then

		LINUX_BINARY_EXISTS=true

		options+=("Launch Pulsar (Linux) using steam-run")
		commands+=("run_with_steam_run_linux")

		options+=("Launch Pulsar (Linux) using nix-shell")
		commands+=("run_with_nix_shell_linux")

		chmod +x "${PULSAR_BINARY_LINUX}"

	fi

	if [[ -f $PULSAR_BINARY_WINDOWS ]]; then

		WINDOWS_BINARY_EXISTS=true

		options+=("Launch Pulsar (Windows) using Proton Caller")
		commands+=("run_with_proton_caller_windows")

		chmod +x "${PULSAR_BINARY_WINDOWS}"

	fi

	# Check if any binaries exist
	if [[ $LINUX_BINARY_EXISTS == false && $WINDOWS_BINARY_EXISTS == false ]]; then
		echo "Error: No Pulsar binaries found!"
		echo "Linux binary: $PULSAR_BINARY_LINUX"
		echo "Windows binary: $PULSAR_BINARY_WINDOWS"
		echo "Please ensure Pulsar is installed in the correct directory."
		exit 1
	fi

	# Add exit option
	options+=("Exit")
	commands+=("exit_script")

	# Common setup (same for all methods)
	setup_env || {
		echo "Error: Failed to setup environment"
		exit 1
	}

	setup_packages || {
		echo "Error: Failed to setup packages"
		exit 1
	}

	setup_library_paths || {
		echo "Error: Failed to setup library paths"
		exit 1
	}

	setup_launch_options || {
		echo "Error: Failed to setup launch options"
		exit 1
	}

	# Show menu and get user choice
	echo "=================================="
	echo "      Pulsar Launch Options      "
	echo "=================================="

	select opt in "${options[@]}"; do
		if [[ $REPLY -ge 1 && $REPLY -le ${#options[@]} ]]; then
			echo "You selected: $opt"

			# Get the corresponding command
			command_index=$((REPLY - 1))
			command="${commands[$command_index]}"

			case $command in
			"run_with_steam_run_linux")
				PULSAR_BINARY="$PULSAR_BINARY_LINUX"
				run_with_steam_run "$@"
				;;
			"run_with_nix_shell_linux")
				PULSAR_BINARY="$PULSAR_BINARY_LINUX"
				run_with_nix_shell "$@"
				;;
			"run_with_proton_caller_windows")
				PULSAR_BINARY="$PULSAR_BINARY_WINDOWS"
				run_with_proton_caller "$@"
				;;
			"exit_script")
				echo "Exiting..."
				exit 0
				;;
			esac
			break
		else
			echo "Invalid option. Please select a number from 1-${#options[@]}."
		fi
	done

	echo "Exiting Pulsar launcher..."
}

# Run main function with all script arguments
main "$@"
