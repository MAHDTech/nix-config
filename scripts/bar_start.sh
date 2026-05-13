#!/bin/bash
set -euo pipefail

# Debug mode (set DEBUG=TRUE to enable verbose output)
export DEBUG=${DEBUG:-FALSE}
if [[ ${DEBUG^^} == "TRUE" ]]; then
	set -x
fi

GAME_BINARY="beyond-all-reason"

# 1. Environment setup for Intel Arc GPU
setup_env() {
	# Wayland settings (since you're using Hyprland)
	export SDL_VIDEODRIVER=wayland,x11
	export XDG_SESSION_TYPE=wayland
	export WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
	export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}

	# Vulkan settings for Intel Arc A730M
	export VK_ICD_FILENAMES
	VK_ICD_FILENAMES="$(nix-build --no-out-link "<nixpkgs>" -A mesa)/share/vulkan/icd.d/intel_icd.x86_64.json"
	export VK_LAYER_MESA_device_select=1 # Force Mesa device selection
	export DRI_PRIME=1                   # For OpenGL fallback or hybrid setups

	# Intel-specific drivers
	export LIBVA_DRIVER_NAME="iHD"
	export VDPAU_DRIVER="va_gl"
	export __GLX_VENDOR_LIBRARY_NAME="mesa"
}

# 2. Package setup
setup_packages() {
	PACKAGES=(
		mesa
		vulkan-loader
		vulkan-tools
		vulkan-validation-layers
		intel-media-driver
		intel-compute-runtime
		libdrm
		libxkbcommon
		wayland
		wayland-protocols
		SDL2
		gamemode # Optional: for performance optimisation
		mangohud # Optional: for performance overlay
	)
}

# 3. Library path setup
setup_library_paths() {
	echo "Preparing LD_LIBRARY_PATH..."
	declare -A lib_to_pkg=(
		["libvulkan.so.1"]="vulkan-loader"
		["libgbm.so.1"]="mesa"
		["libdrm.so.2"]="libdrm"
		["libwayland-client.so.0"]="wayland"
		["libxkbcommon.so.0"]="libxkbcommon"
	)

	LIBS=(
		libvulkan.so.1
		libgbm.so.1
		libdrm.so.2
		libwayland-client.so.0
		libxkbcommon.so.0
	)

	LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
	declare -A store_paths
	for pkg in "${PACKAGES[@]}"; do
		store_paths["$pkg"]=$(nix-build --no-out-link "<nixpkgs>" -A "$pkg" 2>/dev/null || true)
	done

	for lib in "${LIBS[@]}"; do
		pkg="${lib_to_pkg[$lib]}"
		if [ -n "$pkg" ] && [ -n "${store_paths[$pkg]}" ]; then
			lib_path=$(find "${store_paths[$pkg]}" -name "$lib" 2>/dev/null | head -n 1)
			if [ -n "$lib_path" ]; then
				lib_dir=$(dirname "$lib_path")
				LIBRARY_PATH="$lib_dir:$LIBRARY_PATH"
				echo "Found $lib in $lib_dir"
			else
				echo "Warning: $lib not found in $pkg"
			fi
		else
			echo "Warning: No store path for $pkg"
		fi
	done

	LIBRARY_PATH=$(echo "$LIBRARY_PATH" | tr ':' '\n' | sort -u | tr '\n' ':' | sed 's/:$//')
	export LD_LIBRARY_PATH="$LIBRARY_PATH"
	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
	fi
}

# 4. Launch the game
run_game() {
	echo "Starting Beyond All Reason..."
	if [[ ${DEBUG^^} == "TRUE" ]]; then
		echo "Debug: Testing library resolution"
		nix-shell -p "${PACKAGES[@]}" --run "ldd $GAME_BINARY"
	fi

	# Launch with gamemode and mangohud for performance
	nix-shell -p "${PACKAGES[@]}" --run "gamemoderun mangohud $GAME_BINARY"
}

# Main execution
main() {
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
	run_game "$@"
}

main "$@"
