#!/usr/bin/env bash

# GPU burn-in, acceleration, and rendering test suite
# Designed to be SCP'd to a box and run over SSH.
# All visual tests render on the physical display.
#
# Usage:
#   ./test-gpu.sh [DURATION] [RESOLUTION]
#   ./test-gpu.sh 60              # Run each test for 60 seconds
#   ./test-gpu.sh 30 2560x1440   # 30s per test at specific resolution
#   BURN_IN=1 ./test-gpu.sh 60   # Include sustained burn-in phase

set -euo pipefail

###############################################################################
# Configuration - exported so they survive into nix-shell
###############################################################################

export GPU_TEST_DURATION=${1:-60}
export GPU_TEST_USER_RES=${2:-}
export GPU_TEST_BURN_IN=${BURN_IN:-60}
export GPU_TEST_BURN_DURATION=${BURN_DURATION:-300}
export GPU_TEST_SKIP_INFO=${SKIP_INFO:-0}
export GPU_TEST_LOG_FILE=${LOG_FILE:-/tmp/gpu-test-$(date +%Y%m%d-%H%M%S).log}

###############################################################################
# Display detection (before entering nix-shell)
###############################################################################

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
	# Try to find an active X session
	display=$(w -hs 2>/dev/null | awk '{print $3}' | grep -E '^:[0-9]' | head -n1 || true)
	if [ -n "$display" ]; then
		export DISPLAY="$display"
		echo "Auto-detected DISPLAY=$DISPLAY from active session"
	else
		# Try systemd loginctl
		session_id=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -n1 || true)
		if [ -n "$session_id" ]; then
			seat_display=$(loginctl show-session "$session_id" -p Display --value 2>/dev/null || true)
			if [ -n "$seat_display" ]; then
				export DISPLAY="$seat_display"
				echo "Auto-detected DISPLAY=$DISPLAY from loginctl"
			fi
		fi
	fi

	# Try Wayland
	if [ -z "${DISPLAY:-}" ]; then
		wl_display=$(find /run/user/*/wayland-* -maxdepth 0 -name 'wayland-[0-9]*' 2>/dev/null | head -n1 || true)
		if [ -n "$wl_display" ]; then
			export WAYLAND_DISPLAY
			WAYLAND_DISPLAY=$(basename "$wl_display")
			export XDG_RUNTIME_DIR
			XDG_RUNTIME_DIR=$(dirname "$wl_display")
			echo "Auto-detected WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
		fi
	fi
fi

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
	echo "ERROR: Neither DISPLAY nor WAYLAND_DISPLAY is set or auto-detected."
	echo "  Tip: Run with: DISPLAY=:0 $0 $*"
	exit 1
fi

echo ""
echo "=========================================="
echo "  GPU Acceleration & Benchmark Test Suite"
echo "=========================================="
echo "Duration per test : ${GPU_TEST_DURATION}s"
echo "Burn-in mode      : $([ "$GPU_TEST_BURN_IN" = "1" ] && echo "ENABLED (${GPU_TEST_BURN_DURATION}s)" || echo "disabled")"
echo "Log file          : $GPU_TEST_LOG_FILE"
echo "Display           : DISPLAY=${DISPLAY:-unset}  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
echo ""

###############################################################################
# Enter nix-shell with all required packages
###############################################################################

exec nix-shell -p \
	mesa-demos \
	vulkan-tools \
	vkmark \
	glmark2 \
	xorg.xrandr \
	kmscube \
	ffmpeg-full \
	pciutils \
	stress-ng \
	--run bash\ /dev/stdin <<'INNER_SCRIPT'

set -uo pipefail

# Read config from exported environment
DURATION="$GPU_TEST_DURATION"
BURN_IN="$GPU_TEST_BURN_IN"
BURN_DURATION="$GPU_TEST_BURN_DURATION"
SKIP_INFO="$GPU_TEST_SKIP_INFO"
LOG_FILE="$GPU_TEST_LOG_FILE"
USER_RES="$GPU_TEST_USER_RES"

###############################################################################
# Helpers
###############################################################################
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

function banner() {
	echo ""
	echo -e "${CYAN}${BOLD}==========================================${NC}"
	echo -e "${CYAN}${BOLD}  $1${NC}"
	echo -e "${CYAN}${BOLD}==========================================${NC}"
}

function section() {
	echo ""
	echo -e "${YELLOW}------------------------------------------${NC}"
	echo -e "${YELLOW}  $1${NC}"
	echo -e "${YELLOW}------------------------------------------${NC}"
}

function ok()      { echo -e "${GREEN}[OK]${NC} $1"; }

function warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

function fail()    { echo -e "${RED}[FAIL]${NC} $1"; }

function has_cmd() { command -v "$1" &>/dev/null; }

function run_test() {
    local name="$1"; shift
    section "$name"
    set +e
    "$@"
    local rc=$?
    set -e
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 124 ]; then
        ok "$name completed (${DURATION}s)"
    else
        warn "$name exited with code $rc"
    fi
}

###############################################################################
# Resolution detection (inside nix-shell where xrandr is available)
###############################################################################
if [ -n "$USER_RES" ]; then
    RESOLUTION="$USER_RES"
    echo "Using user-specified resolution: $RESOLUTION"
else
    RESOLUTION=$(xrandr 2>/dev/null | grep -E ' connected' | grep -o -E '[0-9]+x[0-9]+' | head -n1 || true)
    if [ -z "$RESOLUTION" ]; then
        RESOLUTION="1920x1080"
        warn "Could not auto-detect resolution. Falling back to: $RESOLUTION"
    else
        echo "Auto-detected resolution: $RESOLUTION"
    fi
fi

WIDTH="${RESOLUTION%%x*}"
HEIGHT="${RESOLUTION##*x}"

# Tee all output to log
exec > >(tee -a "$LOG_FILE") 2>&1

###############################################################################
# Phase 1: GPU Info Dump
###############################################################################
if [ "$SKIP_INFO" != "1" ]; then
    banner "Phase 1: GPU Information"

    section "1.1 PCI GPU Devices"
    lspci | grep -iE 'vga|3d|display' || warn "No GPU found via lspci"

    section "1.2 OpenGL Info (glxinfo)"
    if has_cmd glxinfo; then
        glxinfo 2>/dev/null | grep -iE 'renderer|vendor|version|direct rendering' || warn "glxinfo failed"
    else
        warn "glxinfo not available"
    fi

    section "1.3 Vulkan Info"
    if has_cmd vulkaninfo; then
        vulkaninfo --summary 2>/dev/null || vulkaninfo 2>/dev/null | head -40 || warn "vulkaninfo failed"
    else
        warn "vulkaninfo not available"
    fi

    section "1.4 DRM/KMS Devices"
    ls -la /dev/dri/ 2>/dev/null || warn "No /dev/dri found"
    for card in /dev/dri/card*; do
        if [ -e "$card" ]; then
            echo "  $card"
            cat "/sys/class/drm/$(basename "$card")/device/vendor" 2>/dev/null && echo "" || true
        fi
    done

    section "1.5 GPU Kernel Driver"
    lspci -k 2>/dev/null | grep -A3 -iE 'vga|3d|display' || warn "Could not query kernel drivers"
fi

###############################################################################
# Phase 2: Visual Rendering Tests (appear on physical display)
###############################################################################
banner "Phase 2: Visual Rendering Benchmarks (${DURATION}s each)"

# 2.1 glxgears - Classic OpenGL spinning gears
run_test "2.1 OpenGL - glxgears (fullscreen, vsync off)" \
    env vblank_mode=0 timeout "${DURATION}s" glxgears -fullscreen -geometry "$RESOLUTION"

# 2.2 vkcube - Vulkan spinning cube
if has_cmd vkcube; then
    run_test "2.2 Vulkan - vkcube (spinning cube)" \
        timeout "${DURATION}s" vkcube --width "$WIDTH" --height "$HEIGHT"
else
    warn "vkcube not available, skipping"
fi

# 2.3 vkmark - Vulkan benchmark suite
run_test "2.3 Vulkan - vkmark (fullscreen, immediate present)" \
    env MESA_VK_WSI_PRESENT_MODE=immediate timeout "${DURATION}s" vkmark --fullscreen --size "$RESOLUTION"

# 2.4 glmark2 - OpenGL benchmark (full suite)
run_test "2.4 OpenGL - glmark2 (full benchmark, vsync off)" \
    env vblank_mode=0 timeout "${DURATION}s" glmark2 --fullscreen --size "$RESOLUTION"

###############################################################################
# Phase 3: Targeted Scene Benchmarks (glmark2 individual scenes)
###############################################################################
banner "Phase 3: Targeted GPU Capability Tests (${DURATION}s each)"

SCENES=(
    "shading:shading=phong"
    "shading:shading=cel"
    "texture:texture-filter=trilinear"
    "buffer:update-method=subdata"
    "shadow"
    "conditionals:fragment-steps=5"
    "build:use-vbo=true"
    "effect2d:kernel=blur"
    "desktop"
    "jellyfish"
)

for scene_spec in "${SCENES[@]}"; do
    run_test "3.x glmark2 scene: $scene_spec" \
        env vblank_mode=0 timeout "${DURATION}s" glmark2 --fullscreen --size "$RESOLUTION" \
        --benchmark "$scene_spec"
done

###############################################################################
# Phase 4: KMS/DRM Direct Rendering (bypasses compositor)
###############################################################################
banner "Phase 4: KMS/DRM Direct Rendering (${DURATION}s)"

if has_cmd kmscube; then
    section "4.1 kmscube (direct KMS scanout)"
    echo "NOTE: kmscube renders directly via KMS/DRM, bypassing the compositor."
    echo "      This may briefly take over the display."

    if [ "$(id -u)" -eq 0 ]; then
        run_test "4.1 KMS - kmscube" timeout "${DURATION}s" kmscube
    else
        run_test "4.1 KMS - kmscube (non-root, may fail)" timeout "${DURATION}s" kmscube || true
    fi
else
    warn "kmscube not available, skipping KMS test"
fi

###############################################################################
# Phase 5: Hardware Video Decode
###############################################################################
banner "Phase 5: Hardware Video Decode"

section "5.1 VA-API / VDPAU HW decode test"
echo "Generating a synthetic test video and decoding with hardware acceleration..."

TMPVID="/tmp/gpu-test-video.mp4"

# Generate a test pattern video using the configured duration
ffmpeg -y -f lavfi -i "testsrc=duration=${DURATION}:size=${RESOLUTION}:rate=60" \
    -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
    "$TMPVID" 2>/dev/null

if [ -f "$TMPVID" ]; then
    echo ""
    echo "Attempting VA-API hardware decode of ${DURATION}s @ ${RESOLUTION} 60fps..."
    set +e
    ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
        -i "$TMPVID" -benchmark -f null - 2>&1 | tail -5
    VAAPI_RC=$?
    set -e
    if [ $VAAPI_RC -eq 0 ]; then
        ok "VA-API hardware decode succeeded"
    else
        warn "VA-API decode failed (rc=$VAAPI_RC), trying software decode for comparison..."
    fi

    echo ""
    echo "Software decode (baseline comparison)..."
    ffmpeg -i "$TMPVID" -benchmark -f null - 2>&1 | tail -5
    ok "Software decode completed"

    rm -f "$TMPVID"
else
    fail "Could not generate test video"
fi

###############################################################################
# Phase 6: Sustained Burn-In (optional)
###############################################################################
if [ "$BURN_IN" = "1" ]; then
    banner "Phase 6: Sustained GPU Burn-In (${BURN_DURATION}s)"

    section "6.1 glmark2 sustained stress"
    echo "Running glmark2 in a loop for ${BURN_DURATION} seconds..."
    echo "Monitor GPU temperature with: watch -n1 'cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null || sensors'"

    BURN_END=$(($(date +%s) + BURN_DURATION))
    BURN_ITERATIONS=0

    while [ "$(date +%s)" -lt "$BURN_END" ]; do
        BURN_ITERATIONS=$((BURN_ITERATIONS + 1))
        REMAINING=$(( BURN_END - $(date +%s) ))
        echo ""
        echo "--- Burn-in iteration $BURN_ITERATIONS (${REMAINING}s remaining) ---"
        # Each iteration runs for DURATION seconds or remaining time, whichever is less
        ITER_TIME=$DURATION
        if [ "$REMAINING" -lt "$ITER_TIME" ]; then
            ITER_TIME=$REMAINING
        fi
        env vblank_mode=0 timeout "${ITER_TIME}s" glmark2 --fullscreen --size "$RESOLUTION" 2>&1 | tail -3 || true
    done

    ok "Burn-in completed after $BURN_ITERATIONS iterations"

    if has_cmd stress-ng; then
        section "6.2 stress-ng GPU compute stress (${DURATION}s)"
        run_test "6.2 stress-ng GPU" timeout "${DURATION}s" stress-ng --gpu 0 --gpu-ops 1000 --metrics-brief
    fi
fi

###############################################################################
# Summary
###############################################################################
banner "Test Suite Complete"
echo ""
echo "Log saved to: $LOG_FILE"
echo ""
echo "Quick reference commands for monitoring:"
echo "  GPU temp    : cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input"
echo "  GPU usage   : cat /sys/class/drm/card*/device/gpu_busy_percent"
echo "  Watch temps : watch -n1 sensors"
echo "  dmesg errs  : dmesg | grep -iE 'gpu|drm|amdgpu|nvidia|i915|error|fault'"
echo ""

INNER_SCRIPT
