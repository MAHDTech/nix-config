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
VK_ICD_FILENAMES="$(nix-build --no-out-link "<nixpkgs>" -A mesa.drivers)/share/vulkan/icd.d/intel_icd.x86_64.json"
export VK_ICD_FILENAMES

# Ensure the binary is executable
chmod +x "${PULSAR_BINARY}"

# List of required Nix packages
# Added wayland-protocols for wayland-scanner
pkgs=(
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

# List of missing libraries from ldd output
libs=(
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

echo "Preparing LD Library PATH..."

# Cache store paths for each package to avoid redundant nix-build calls
declare -A store_paths
for pkg in "${pkgs[@]}"; do
	store_paths["$pkg"]=$(nix-build --no-out-link "<nixpkgs>" -A "$pkg" 2>/dev/null || true)
done

# Build LD_LIBRARY_PATH by finding the exact library files
#LD_LIBRARY_PATH=""
LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
for lib in "${libs[@]}"; do
	pkg="${lib_to_pkg[$lib]}"
	if [ -n "$pkg" ]; then
		store_path="${store_paths[$pkg]}"
		if [ -n "$store_path" ]; then
			# Search for the library file in the entire store path
			lib_path=$(find "$store_path" -name "$lib" 2>/dev/null | head -n 1)
			if [ -n "$lib_path" ]; then
				# Add the directory containing the library to LD_LIBRARY_PATH
				lib_dir=$(dirname "$lib_path")
				LD_LIBRARY_PATH="$lib_dir:$LD_LIBRARY_PATH"
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

# Remove duplicates and trailing colon, then export LD_LIBRARY_PATH
LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | sort -u | tr '\n' ':' | sed 's/:$//')
export LD_LIBRARY_PATH

if [[ ${DEBUG^^} == "TRUE" ]]; then
	# Debug: Print LD_LIBRARY_PATH
	echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

echo "Starting Pulsar in Nix Shell..."

if [[ ${DEBUG^^} == "TRUE" ]]; then
	nix-shell -p "${pkgs[@]}" --run "ldd ${PULSAR_BINARY}"
fi

nix-shell -p "${pkgs[@]}" \
	--verbose \
	--run "${PULSAR_BINARY} Pulsar $*"

echo "Exiting Pulsar in Nix Shell..."
