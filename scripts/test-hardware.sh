#!/usr/bin/env bash

# Hardware stability and stress test suite (CPU, Memory, and GPU)
# Designed to be run on NixOS hosts to verify system stability.
# All visual GPU tests render on the physical display.
#
# Usage:
#   ./test-hardware.sh [DURATION] [RESOLUTION]
#   ./test-hardware.sh 60              # Run each test for 60 seconds (default)
#   ./test-hardware.sh 30 2560x1440   # 30s per test at specific resolution
#   BURN_IN=1 ./test-hardware.sh 60   # Include sustained combined burn-in phase
#

set -euo pipefail

# Configuration defaults for logging
export HW_TEST_LOG_FILE=${LOG_FILE:-${HW_TEST_LOG_FILE:-/tmp/hardware-test-$(date +%Y%m%d-%H%M%S).log}}

# 1. Identify the real user, UID, and home directory
if [ "$(id -u)" -eq 0 ]; then
	REAL_UID="${SUDO_UID:-}"
	REAL_USER="${SUDO_USER:-}"
	if [ -z "$REAL_UID" ] || [ -z "$REAL_USER" ]; then
		# Find the active GUI session user
		active_session=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -n1 || true)
		if [ -n "$active_session" ]; then
			REAL_USER=$(loginctl show-session "$active_session" -p Name --value 2>/dev/null || true)
			REAL_UID=$(loginctl show-session "$active_session" -p User --value 2>/dev/null || true)
		fi
		if [ -z "$REAL_USER" ]; then
			REAL_USER=$(w -hs 2>/dev/null | awk '{print $1}' | grep -v 'root' | head -n1 || true)
			if [ -n "$REAL_USER" ]; then
				REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || true)
			fi
		fi
	fi
else
	REAL_UID="$(id -u)"
	REAL_USER="$(id -un)"
fi

export REAL_UID="${REAL_UID:-1000}"
export REAL_USER="${REAL_USER:-mahdtech}"
export XDG_RUNTIME_DIR="/run/user/$REAL_UID"

# 2. Detect Wayland Display and Hyprland Signature
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
	wl_socket=$(find "$XDG_RUNTIME_DIR"/wayland-* -maxdepth 0 -name 'wayland-[0-9]*' 2>/dev/null | head -n1 || true)
	if [ -n "$wl_socket" ]; then
		WAYLAND_DISPLAY=$(basename "$wl_socket")
		export WAYLAND_DISPLAY
		echo "Auto-detected WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
	fi
fi

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
	sig_dir=$(find "$XDG_RUNTIME_DIR/hypr/" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1 || true)
	if [ -n "$sig_dir" ]; then
		HYPRLAND_INSTANCE_SIGNATURE=$(basename "$sig_dir")
		export HYPRLAND_INSTANCE_SIGNATURE
		echo "Auto-detected HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"
	fi
fi

# 3. Detect X11 Display & Xauthority
if [ -z "${DISPLAY:-}" ]; then
	# Try loginctl
	session_id=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -n1 || true)
	if [ -n "$session_id" ]; then
		seat_display=$(loginctl show-session "$session_id" -p Display --value 2>/dev/null || true)
		if [ -n "$seat_display" ]; then
			export DISPLAY="$seat_display"
			echo "Auto-detected DISPLAY=$DISPLAY from loginctl"
		fi
	fi
	# Try w
	if [ -z "${DISPLAY:-}" ]; then
		display=$(w -hs 2>/dev/null | awk '{print $3}' | grep -E '^:[0-9]' | head -n1 || true)
		if [ -n "$display" ]; then
			export DISPLAY="$display"
			echo "Auto-detected DISPLAY=$DISPLAY from active session"
		fi
	fi
	# Fallback if Wayland is active but DISPLAY is not set
	if [ -z "${DISPLAY:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
		export DISPLAY=":0"
		echo "Wayland active; falling back to default DISPLAY=$DISPLAY"
	fi
fi

if [ -z "${XAUTHORITY:-}" ]; then
	USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 || echo "/home/$REAL_USER")
	if [ -f "$USER_HOME/.Xauthority" ]; then
		export XAUTHORITY="$USER_HOME/.Xauthority"
	elif [ -f "$XDG_RUNTIME_DIR/gdm/Xauthority" ]; then
		export XAUTHORITY="$XDG_RUNTIME_DIR/gdm/Xauthority"
	fi
fi

# 4. Privilege Elevation & Suspend Inhibition
if [ "$(id -u)" -ne 0 ]; then
	echo "Elevating privileges to root via sudo and inhibiting suspend..."
	exec sudo env \
		DISPLAY="${DISPLAY:-}" \
		WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
		XAUTHORITY="${XAUTHORITY:-}" \
		HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
		REAL_UID="$REAL_UID" \
		REAL_USER="$REAL_USER" \
		SYSTEMD_INHIBIT_ACTIVE=1 \
		systemd-inhibit \
		--what="idle:sleep" \
		--who="test-hardware.sh" \
		--why="Running hardware stability and stress tests" \
		"$0" "$@"
fi

if [ -z "${SYSTEMD_INHIBIT_ACTIVE:-}" ] && command -v systemd-inhibit >/dev/null 2>&1; then
	export SYSTEMD_INHIBIT_ACTIVE=1
	echo "Re-executing script under systemd-inhibit to prevent system suspend/sleep..."
	exec systemd-inhibit \
		--what="idle:sleep" \
		--who="test-hardware.sh" \
		--why="Running hardware stability and stress tests" \
		"$0" "$@"
fi

# Configuration
export HW_TEST_DURATION=${1:-60}
export HW_TEST_USER_RES=${2:-}
export HW_TEST_BURN_IN=${BURN_IN:-0}
export HW_TEST_BURN_DURATION=${BURN_DURATION:-300}
export HW_TEST_SKIP_INFO=${SKIP_INFO:-0}

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
	echo "ERROR: Neither DISPLAY nor WAYLAND_DISPLAY is set or auto-detected."
	echo "  Tip: Run with: DISPLAY=:0 $0 $*"
	exit 1
fi

# Enter nix-shell with all required packages
if [ -z "${IN_NIX_SHELL:-}" ]; then
	export IN_NIX_SHELL=1
	echo "Launching nix-shell with required stress test dependencies..."
	exec nix-shell -p \
		mesa-demos \
		vulkan-tools \
		glmark2 \
		xrandr \
		pciutils \
		stress-ng \
		vkmark \
		kmscube \
		ffmpeg \
		--run "$(printf '%q ' "$0" "$@")"
fi

# ---------------------------------------------------------
# Actual execution starts here (now running inside nix-shell)
# ---------------------------------------------------------

echo ""
echo "=========================================="
echo "  Hardware Stress & Stability Test Suite"
echo "=========================================="
echo "Duration per test : ${HW_TEST_DURATION}s"
echo "Burn-in mode      : $([ "$HW_TEST_BURN_IN" = "1" ] && echo "ENABLED (${HW_TEST_BURN_DURATION}s)" || echo "disabled")"
echo "Log file          : $HW_TEST_LOG_FILE"
echo "Display           : DISPLAY=${DISPLAY:-unset}  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
echo ""

DURATION="$HW_TEST_DURATION"
BURN_IN="$HW_TEST_BURN_IN"
BURN_DURATION="$HW_TEST_BURN_DURATION"
SKIP_INFO="$HW_TEST_SKIP_INFO"
LOG_FILE="$HW_TEST_LOG_FILE"
USER_RES="$HW_TEST_USER_RES"

###############################################################################
# Helpers
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

function ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
function fail() { echo -e "${RED}[FAIL]${NC} $1"; }
function has_cmd() { command -v "$1" &>/dev/null; }

function run_test() {
	local name="$1"
	shift
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

# Resolution detection (inside nix-shell where xrandr is available)
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
# Screensaver & Idle Inhibition
###############################################################################
HYPRIDLE_WAS_ACTIVE=0
if sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus" systemctl --user is-active --quiet hypridle.service 2>/dev/null; then
	echo "Temporarily stopping hypridle to prevent screensaver/lockscreen from activating..."
	sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus" systemctl --user stop hypridle.service 2>/dev/null || true
	HYPRIDLE_WAS_ACTIVE=1
fi

cleanup() {
	echo ""
	banner "Restoring System State"
	if [ "$HYPRIDLE_WAS_ACTIVE" -eq 1 ]; then
		echo "Restarting hypridle service..."
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus" systemctl --user start hypridle.service 2>/dev/null || true
	fi
}
trap cleanup EXIT

###############################################################################
# Phase 1: Hardware Info Dump
###############################################################################
if [ "$SKIP_INFO" != "1" ]; then
	banner "Phase 1: Hardware Information"

	section "1.1 CPU Info"
	lscpu 2>/dev/null | grep -E 'Model name|Architecture|CPU\(s\)|Thread\(s\)|BogoMIPS|CPU max MHz' || cat /proc/cpuinfo | grep -E 'model name|processor|BogoMIPS' | head -10 || true

	section "1.2 Memory Info"
	free -h || cat /proc/meminfo | grep -E 'MemTotal|MemFree|Available' || true

	section "1.3 PCI GPU Devices"
	lspci | grep -iE 'vga|3d|display' || warn "No GPU found via lspci"

	section "1.4 OpenGL Info (glxinfo)"
	if has_cmd glxinfo; then
		glxinfo 2>/dev/null | grep -iE 'renderer|vendor|version|direct rendering' || warn "glxinfo failed"
	else
		warn "glxinfo not available"
	fi

	section "1.5 Vulkan Info"
	if has_cmd vulkaninfo; then
		vulkaninfo --summary 2>/dev/null || vulkaninfo 2>/dev/null | head -40 || warn "vulkaninfo failed"
	else
		warn "vulkaninfo not available"
	fi

	section "1.6 DRM/KMS Devices"
	ls -la /dev/dri/ 2>/dev/null || warn "No /dev/dri found"
	for card in /dev/dri/card*; do
		if [ -e "$card" ]; then
			echo "  $card"
			cat "/sys/class/drm/$(basename "$card")/device/vendor" 2>/dev/null && echo "" || true
		fi
	done

	section "1.7 GPU Kernel Driver"
	lspci -k 2>/dev/null | grep -A3 -iE 'vga|3d|display' || warn "Could not query kernel drivers"
fi

###############################################################################
# Phase 2: CPU Stress Tests
###############################################################################
banner "Phase 2: CPU Stress Benchmarks (${DURATION}s)"

if has_cmd stress-ng; then
	run_test "2.1 CPU - stress-ng (Matrix, Vector, CPU methods)" \
		stress-ng --cpu 0 --cpu-method all --timeout "${DURATION}s" --metrics-brief
else
	warn "stress-ng not available, skipping CPU stress tests"
fi

###############################################################################
# Phase 3: Memory (RAM) Stress Tests
###############################################################################
banner "Phase 3: Memory Stress Benchmarks (${DURATION}s)"

if has_cmd stress-ng; then
	run_test "3.1 Memory - stress-ng (Virtual Memory stressor)" \
		stress-ng --vm 0 --vm-bytes 80% --timeout "${DURATION}s" --metrics-brief
else
	warn "stress-ng not available, skipping Memory stress tests"
fi

###############################################################################
# Phase 4: GPU Visual Rendering Tests (appear on physical display)
###############################################################################
banner "Phase 4: GPU Visual Rendering Benchmarks (${DURATION}s each)"

# 4.1 glxgears - Classic OpenGL spinning gears
run_test "4.1 OpenGL - glxgears (fullscreen, vsync off)" \
	env vblank_mode=0 timeout "${DURATION}s" glxgears -fullscreen -geometry "$RESOLUTION"

# 4.2 vkcube - Vulkan spinning cube
if has_cmd vkcube; then
	run_test "4.2 Vulkan - vkcube (spinning cube)" \
		timeout "${DURATION}s" vkcube --width "$WIDTH" --height "$HEIGHT"
else
	warn "vkcube not available, skipping"
fi

# 4.3 vkmark - Vulkan benchmark suite (run forever and let timeout terminate it)
if has_cmd vkmark; then
	run_test "4.3 Vulkan - vkmark (fullscreen, immediate present)" \
		env MESA_VK_WSI_PRESENT_MODE=immediate timeout "${DURATION}s" vkmark --fullscreen --size "$RESOLUTION" --run-forever
else
	warn "vkmark not available, skipping"
fi

# 4.4 glmark2 - OpenGL benchmark (full suite, run forever and let timeout terminate it)
run_test "4.4 OpenGL - glmark2 (full benchmark, vsync off)" \
	env vblank_mode=0 timeout "${DURATION}s" glmark2 --fullscreen --size "$RESOLUTION" --run-forever

###############################################################################
# Phase 5: Targeted Scene Benchmarks (glmark2 individual scenes)
###############################################################################
banner "Phase 5: Targeted GPU Capability Tests (${DURATION}s each)"

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
	run_test "5.x glmark2 scene: $scene_spec" \
		env vblank_mode=0 timeout "${DURATION}s" glmark2 --fullscreen --size "$RESOLUTION" \
		--benchmark "${scene_spec}:duration=${DURATION}"
done

###############################################################################
# Phase 6: KMS/DRM Direct Rendering (bypasses compositor)
###############################################################################
banner "Phase 6: KMS/DRM Direct Rendering (${DURATION}s)"

if has_cmd kmscube; then
	section "6.1 kmscube (direct KMS scanout)"
	echo "NOTE: kmscube renders directly via KMS/DRM, bypassing the compositor."
	echo "      This may briefly take over the display."

	if [ "$(id -u)" -eq 0 ]; then
		run_test "6.1 KMS - kmscube" timeout "${DURATION}s" kmscube
	else
		run_test "6.1 KMS - kmscube (non-root, may fail)" timeout "${DURATION}s" kmscube || true
	fi
else
	warn "kmscube not available, skipping KMS test"
fi

###############################################################################
# Phase 7: Hardware Video Decode
###############################################################################
banner "Phase 7: Hardware Video Decode"

section "7.1 VA-API / VDPAU HW decode test"
echo "Generating a synthetic test video and decoding with hardware acceleration..."

TMPVID="/tmp/hardware-test-video.mp4"

# Generate a short 5-second test pattern video using ffmpeg
ffmpeg -nostdin -y -f lavfi -i "testsrc=duration=5:size=${RESOLUTION}:rate=60" \
	-c:v libx264 -preset ultrafast -pix_fmt yuv420p \
	"$TMPVID" 2>/dev/null

if [ -f "$TMPVID" ]; then
	echo ""
	echo "Attempting VA-API hardware decode in a loop for ${DURATION}s @ ${RESOLUTION} 60fps..."
	set +e
	timeout "${DURATION}s" ffmpeg -nostdin -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
		-stream_loop -1 -i "$TMPVID" -benchmark -f null - 2>&1 | tail -5
	VAAPI_RC=$?
	set -e
	if [ $VAAPI_RC -eq 0 ] || [ $VAAPI_RC -eq 124 ]; then
		ok "VA-API hardware decode succeeded"
	else
		warn "VA-API decode failed (rc=$VAAPI_RC), trying software decode for comparison..."
	fi

	echo ""
	echo "Software decode in a loop (baseline comparison) for ${DURATION}s..."
	set +e
	timeout "${DURATION}s" ffmpeg -nostdin -stream_loop -1 -i "$TMPVID" -benchmark -f null - 2>&1 | tail -5
	SW_RC=$?
	set -e
	if [ $SW_RC -eq 0 ] || [ $SW_RC -eq 124 ]; then
		ok "Software decode completed"
	else
		warn "Software decode failed (rc=$SW_RC)"
	fi

	rm -f "$TMPVID"
else
	fail "Could not generate test video"
fi

###############################################################################
# Phase 8: Sustained Combined Burn-In (optional)
###############################################################################
if [ "$BURN_IN" = "1" ]; then
	banner "Phase 8: Sustained Combined System Burn-In (${BURN_DURATION}s)"
	echo "Running CPU, Memory, and GPU (glmark2) stressors simultaneously..."
	echo "Monitor temperature with: watch -n1 'cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null || sensors'"

	STRESS_PID=""
	if has_cmd stress-ng; then
		echo "Starting background CPU and memory stressors..."
		stress-ng --cpu 0 --vm 0 --vm-bytes 50% --timeout "${BURN_DURATION}s" --metrics-brief &
		STRESS_PID=$!
	fi

	echo "Starting foreground GPU stress loops..."
	BURN_END=$(($(date +%s) + BURN_DURATION))
	BURN_ITERATIONS=0

	while [ "$(date +%s)" -lt "$BURN_END" ]; do
		BURN_ITERATIONS=$((BURN_ITERATIONS + 1))
		REMAINING=$((BURN_END - $(date +%s)))
		if [ "$REMAINING" -le 0 ]; then break; fi

		echo ""
		echo "--- Burn-in iteration $BURN_ITERATIONS (${REMAINING}s remaining) ---"
		# Each iteration runs for DURATION seconds or remaining time, whichever is less
		ITER_TIME=$DURATION
		if [ "$REMAINING" -lt "$ITER_TIME" ]; then
			ITER_TIME=$REMAINING
		fi
		env vblank_mode=0 timeout "${ITER_TIME}s" glmark2 --fullscreen --size "$RESOLUTION" --run-forever >/dev/null 2>&1 || true
	done

	if [ -n "$STRESS_PID" ]; then
		echo "Waiting for background stressors to complete..."
		wait "$STRESS_PID" || true
	fi

	ok "Combined Burn-in completed after $BURN_ITERATIONS iterations"
fi

###############################################################################
# Summary
###############################################################################
banner "Test Suite Complete"
echo ""
echo "Log saved to: $LOG_FILE"
echo ""
echo "Quick reference commands for monitoring:"
echo "  CPU temp    : cat /sys/class/thermal/thermal_zone*/temp"
echo "  GPU temp    : cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input"
echo "  GPU usage   : cat /sys/class/drm/card*/device/gpu_busy_percent"
echo "  Watch temps : watch -n1 sensors"
echo "  dmesg errs  : dmesg | grep -iE 'gpu|drm|panthor|amdgpu|nvidia|i915|error|fault'"
echo ""

# Parse metrics from the log file
cpu_ops=$(awk '/stress-ng: metric:.*cpu / {print $(NF-1)}' "$LOG_FILE" | tail -n1 || true)
mem_ops=$(awk '/stress-ng: metric:.*vm / {print $(NF-1)}' "$LOG_FILE" | tail -n1 || true)
glxgears_fps=$(awk '/frames in.*seconds/ {print $(NF-1)}' "$LOG_FILE" | tail -n1 || true)

if grep -q "\[OK\] 4.2 Vulkan - vkcube" "$LOG_FILE"; then
	vkcube_status="Success"
else
	vkcube_status="Failed/Skipped"
fi

vkmark_score=$(awk -F': ' '/vkmark Score/ {print $2}' "$LOG_FILE" | tail -n1 || true)
glmark2_score=$(awk -F': ' '/glmark2 Score/ {print $2}' "$LOG_FILE" | tail -n1 || true)

vaapi_block=$(sed -n '/Attempting VA-API hardware decode/,/Software decode/p' "$LOG_FILE" || true)
vaapi_speed=$(echo "$vaapi_block" | grep -o -E 'speed=\s*[0-9.]*x' | tail -n1 | tr -d ' ' | sed 's/speed=//' || true)
vaapi_frames=$(echo "$vaapi_block" | grep -o -E 'frame=\s*[0-9]+' | tail -n1 | awk '{print $2}' || true)

sw_block=$(sed -n '/Software decode in a loop/,/Phase 8\|Test Suite Complete/p' "$LOG_FILE" || true)
sw_speed=$(echo "$sw_block" | grep -o -E 'speed=\s*[0-9.]*x' | tail -n1 | tr -d ' ' | sed 's/speed=//' || true)
sw_frames=$(echo "$sw_block" | grep -o -E 'frame=\s*[0-9]+' | tail -n1 | awk '{print $2}' || true)

# Generate the results summary log file
SUMMARY_FILE="/tmp/test-hardware-${REAL_USER}.log"
{
	echo "=========================================="
	echo "  Hardware Stress Test Summary"
	echo "  Date       : $(date)"
	echo "  Duration   : ${DURATION}s per test"
	echo "  Resolution : ${RESOLUTION}"
	echo "=========================================="
	echo ""

	echo "--- CPU & Memory ---"
	if [ -n "$cpu_ops" ]; then
		echo "CPU stress-ng (all methods) : $cpu_ops bogo ops/s"
	fi
	if [ -n "$mem_ops" ]; then
		echo "Memory stress-ng (VM)       : $mem_ops bogo ops/s"
	fi
	echo ""

	echo "--- GPU / Rendering ---"
	if [ -n "$glxgears_fps" ]; then
		echo "glxgears (OpenGL)           : $glxgears_fps FPS"
	fi
	echo "vkcube (Vulkan)             : $vkcube_status"
	if [ -n "$vkmark_score" ]; then
		echo "vkmark Score (Vulkan)       : $vkmark_score"
	fi
	if [ -n "$glmark2_score" ]; then
		echo "glmark2 Score (OpenGL ES)   : $glmark2_score"
	fi
	echo ""

	echo "--- GPU Targeted Scenes ---"
	grep "FPS:" "$LOG_FILE" | uniq | while read -r line; do
		echo "  $line"
	done
	echo ""

	echo "--- Hardware Video Decode ---"
	if [ -n "$vaapi_speed" ]; then
		echo "VA-API Hardware Decode      : $vaapi_speed (${vaapi_frames:-0} frames)"
	fi
	if [ -n "$sw_speed" ]; then
		echo "Software Decode (Baseline)  : $sw_speed (${sw_frames:-0} frames)"
	fi
	echo ""
} >"$SUMMARY_FILE"

# Ensure the log and summary files are owned by the real user
if [ "$(id -u)" -eq 0 ] && [ -n "${REAL_USER:-}" ]; then
	chown "${REAL_USER}:${REAL_USER}" "$SUMMARY_FILE" "$HW_TEST_LOG_FILE" 2>/dev/null || true
fi

# Print summary to terminal
echo "=========================================="
echo "  Results Summary"
echo "=========================================="
cat "$SUMMARY_FILE"
echo "=========================================="
echo "Summary log saved to: $SUMMARY_FILE"
echo ""
