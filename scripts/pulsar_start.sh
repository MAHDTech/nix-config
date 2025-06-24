#!/bin/bash

clear

set -euo pipefail

export DEBUG=${DEBUG:-FALSE}

if [[ ${DEBUG^^} == "TRUE" ]]; then
	set -x
fi

# Pulsar project
PULSAR_HOME="${HOME}/Games/PulsarGame"
PULSAR_BINARY="${PULSAR_HOME}/Pulsar/Binaries/Linux/Pulsar-Linux-Shipping"

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

	# Ensure the binary is executable
	chmod +x "${PULSAR_BINARY}"
}

# 2. Common package setup
setup_packages() {
	# List of required Nix packages
	PACKAGES=(
		# Common
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
	)
}

# 3. Common library path setup
setup_library_paths() {
	echo "Preparing LD Library PATH..."

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
		nix-shell -p "${PACKAGES[@]}" steam-run --run "LD_LIBRARY_PATH='$LIBRARY_PATH' steam-run ldd '${PULSAR_BINARY}'"
	fi

	nix-shell -p "${PACKAGES[@]}" steam-run --run "LD_LIBRARY_PATH='$LIBRARY_PATH' steam-run '${PULSAR_BINARY}' Pulsar $*"
}

# 4b. Nix-shell execution method
run_with_nix_shell() {
	echo "Starting Pulsar with nix-shell..."
	echo "Using enhanced LD_LIBRARY_PATH management..."

	export LD_LIBRARY_PATH="$LIBRARY_PATH"

	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "Debug: Testing library resolution with nix-shell"
		nix-shell -p "${PACKAGES[@]}" --run "ldd ${PULSAR_BINARY}"
	fi

	nix-shell -p "${PACKAGES[@]}" \
		--verbose \
		--run "${PULSAR_BINARY} Pulsar $*"
}

# Main execution
main() {
	# Check if Pulsar binary exists
	if [[ ! -f $PULSAR_BINARY ]]; then
		echo "Error: Pulsar binary not found at $PULSAR_BINARY"
		echo "Please ensure Pulsar is installed in the correct directory."
		exit 1
	fi

	# Common setup (same for both methods)
	setup_env
	setup_packages
	setup_library_paths

	# Show menu and get user choice
	echo "=================================="
	echo "      Pulsar Launch Options      "
	echo "=================================="

	options=(
		"Launch Pulsar using steam-run"
		"Launch Pulsar using nix-shell"
		"Exit"
	)

	select opt in "${options[@]}"; do
		case $REPLY in
		1)
			echo "You selected: $opt"
			run_with_steam_run "$@"
			break
			;;
		2)
			echo "You selected: $opt"
			run_with_nix_shell "$@"
			break
			;;
		3)
			echo "Exiting..."
			exit 0
			;;
		*)
			echo "Invalid option. Please select a number from 1-3."
			;;
		esac
	done

	echo "Exiting Pulsar launcher..."
}

# Run main function with all script arguments
main "$@"
