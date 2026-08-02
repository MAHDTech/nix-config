#!/usr/bin/env bash
# orion-uat — user acceptance test for Radxa Orion O6 (CIX P1) on mainline 7.2.
#
# Runs a sustained stress phase per engine and samples telemetry throughout, so
# a pass means "held up under load", not "enumerated once". Each phase records
# frequency residency, temperature, throttling and the kernel ring buffer, and
# every phase is judged on evidence collected during the run.
#
# Usage:
#   orion-uat.sh [--minutes N] [--phase cpu|gpu|npu|all] [--outdir DIR]
#
# Default is 30 minutes per phase, matching the acceptance criteria.
# Phases run sequentially on purpose: run them together and a thermal result
# cannot be attributed to any one engine.
#
# The GPU phase is offscreen and headless so it works over SSH. On-screen visual
# confirmation (no corruption, no tearing) still needs a human at the display and
# is deliberately NOT claimed here — see the note the GPU phase prints.

set -uo pipefail

MINUTES=30
PHASE=all
OUTDIR=""

while [ $# -gt 0 ]; do
	case "$1" in
	--minutes)
		MINUTES="$2"
		shift 2
		;;
	--phase)
		PHASE="$2"
		shift 2
		;;
	--outdir)
		OUTDIR="$2"
		shift 2
		;;
	*)
		echo "unknown argument: $1" >&2
		exit 64
		;;
	esac
done

SECS=$((MINUTES * 60))
[ -n "$OUTDIR" ] || OUTDIR="/var/tmp/orion-uat-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTDIR"

GPU_DEVFREQ=/sys/class/devfreq/15000000.gpu
NIXPKGS="nixpkgs"

say() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }

# ── telemetry ────────────────────────────────────────────────────────────────
# Sampled once a second for the whole phase and summarised afterwards. Recording
# raw samples rather than a start/end pair is what lets us distinguish "ran at
# full clock" from "spiked once then throttled to nothing".
sample_telemetry() {
	local out="$1" end=$(($(date +%s) + SECS + 5))
	echo "epoch,cpu_khz_max,gpu_hz,temp_max_mC,throttle_count" >"$out"
	while [ "$(date +%s)" -lt "$end" ]; do
		local cpu gpu temp thr
		cpu=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | sort -n | tail -1)
		gpu=$(cat "$GPU_DEVFREQ/cur_freq" 2>/dev/null)
		temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
		thr=$(cat /sys/devices/system/cpu/cpu*/thermal_throttle/*_throttle_count 2>/dev/null |
			awk '{s+=$1} END{print s+0}')
		echo "$(date +%s),${cpu:-0},${gpu:-0},${temp:-0},${thr:-0}" >>"$out"
		sleep 1
	done
}

summarise() {
	local csv="$1" label="$2"
	awk -F, -v L="$label" '
    NR>1 {
      n++
      if ($2>cmax) cmax=$2; if ($3>gmax) gmax=$3
      if ($4>tmax) tmax=$4
      csum+=$2; gsum+=$3; tsum+=$4
      if ($3>0) { gfreq[$3]++ }
    }
    END {
      if (!n) { print "   no samples"; exit }
      printf "   samples          : %d over %d s\n", n, n
      printf "   CPU max / mean   : %.2f GHz / %.2f GHz\n", cmax/1e6, (csum/n)/1e6
      if (gmax>0) printf "   GPU max / mean   : %d MHz / %d MHz\n", gmax/1e6, (gsum/n)/1e6
      printf "   temp max / mean  : %.1f C / %.1f C\n", tmax/1000, (tsum/n)/1000
      if (gmax>0) { printf "   GPU freq residency:\n"; for (f in gfreq) printf "     %d MHz : %d s\n", f/1e6, gfreq[f] }
    }' "$csv"
}

# Snapshot the ring buffer before any phase, so dmesg_verdict only judges lines
# that could have been produced by the run itself.
dmesg_before() { sudo -n dmesg 2>/dev/null | tee "$OUTDIR/dmesg-pre.txt" >/dev/null; }
dmesg_verdict() {
	local out="$1"
	sudo -n dmesg 2>/dev/null | tail -400 >"$out"
	# Anything in here during a stress run is a real failure, not noise.
	if grep -qiE "SError|Internal error|Unable to handle|BUG:|Call trace|hung task|thermal.*critical|GPU fault|MMU fault|watchdog" "$out"; then
		echo "   KERNEL ERRORS DETECTED:"
		grep -iE "SError|Internal error|Unable to handle|BUG:|Call trace|hung task|thermal.*critical|GPU fault|MMU fault|watchdog" "$out" | head -10 | sed 's/^/     /'
		return 1
	fi
	echo "   kernel ring buffer clean (no SError, oops, fault or hung task)"
	return 0
}

# ── CPU ──────────────────────────────────────────────────────────────────────
phase_cpu() {
	say "CPU stress — ${MINUTES} min"
	note "12 cores: 4x Cortex-A720 @ up to 2.6 GHz, 4x A720, 4x A520"
	note "boost = $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null)"

	sample_telemetry "$OUTDIR/cpu.csv" &
	local sampler=$!

	# --cpu 0 uses every online CPU. matrix and vm alongside cpu exercise FPU/SIMD
	# and the memory subsystem, not just the integer pipeline, so a marginal
	# regulator or a memory clock problem has a chance to show up.
	nix shell "$NIXPKGS#stress-ng" --command \
		stress-ng --cpu 0 --matrix 0 --vm 2 --vm-bytes 1G \
		--timeout "${SECS}s" --metrics-brief --times \
		2>&1 | tee "$OUTDIR/cpu-stress.log" | tail -25

	wait $sampler 2>/dev/null
	say "CPU result"
	summarise "$OUTDIR/cpu.csv" cpu
	dmesg_verdict "$OUTDIR/cpu-dmesg.txt"
}

# ── GPU ──────────────────────────────────────────────────────────────────────
phase_gpu() {
	say "GPU stress — ${MINUTES} min"
	note "Mali-G720 Immortalis MC10 via panthor + Mesa panfrost/panvk"
	note "OFFSCREEN: proves shader cores, tiler, MMU, job submission and DVFS."
	note "It does NOT prove absence of visual corruption — that needs a human"
	note "at the display once USB/keyboard and the display driver are working."

	sample_telemetry "$OUTDIR/gpu.csv" &
	local sampler=$!
	local end=$(($(date +%s) + SECS)) run=0

	# glmark2 is a fixed-length benchmark, so loop it to fill the window and keep
	# the GPU continuously busy rather than idling between runs.
	while [ "$(date +%s)" -lt "$end" ]; do
		run=$((run + 1))
		nix shell "$NIXPKGS#glmark2" --command \
			glmark2-es2-gbm --off-screen -b build -b texture -b shading -b bump \
			-b refract -b conditionals -b function -b terrain \
			2>&1 | tee -a "$OUTDIR/gpu-glmark2.log" | grep -E "glmark2 Score|FPS" | tail -3
		note "run $run complete, $((end - $(date +%s)))s remaining"
	done

	wait $sampler 2>/dev/null
	say "GPU result"
	note "scores across $run runs:"
	grep "glmark2 Score" "$OUTDIR/gpu-glmark2.log" | sed 's/^/     /'
	# A score that decays run over run means thermal or power throttling.
	summarise "$OUTDIR/gpu.csv" gpu
	dmesg_verdict "$OUTDIR/gpu-dmesg.txt"
}

# ── NPU ──────────────────────────────────────────────────────────────────────
phase_npu() {
	say "NPU stress — ${MINUTES} min"
	note "ArmChina Zhouyi V3 via armchina_npu (out-of-tree, carried patch)"

	if [ ! -e /dev/aipu ]; then
		note "/dev/aipu absent — loading the module (blacklisted on first boot)"
		sudo -n modprobe armchina_npu 2>&1 | sed 's/^/     /'
		sleep 2
	fi
	if [ ! -e /dev/aipu ]; then
		echo "   FAIL: /dev/aipu still absent; the driver did not bind" >&2
		sudo -n dmesg | grep -iE "aipu|armchina|npu" | tail -20 | sed 's/^/     /'
		return 1
	fi

	local bin="$OUTDIR/aipu-uat"
	nix shell "$NIXPKGS#gcc" --command \
		cc -O2 -Wall -o "$bin" "$(dirname "$0")/aipu-uat.c" || return 1

	sample_telemetry "$OUTDIR/npu.csv" &
	local sampler=$!

	"$bin" --stress "$SECS" 2>&1 | tee "$OUTDIR/npu-uat.log"
	local rc=${PIPESTATUS[0]}

	wait $sampler 2>/dev/null
	say "NPU result"
	note "power domains:"
	sudo -n grep -iE "npu" /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null | sed 's/^/     /'
	note "interrupts:"
	grep -iE "aipu|npu" /proc/interrupts 2>/dev/null | sed 's/^/     /' || note "  (none registered)"
	summarise "$OUTDIR/npu.csv" npu
	dmesg_verdict "$OUTDIR/npu-dmesg.txt"
	return "$rc"
}

# ── run ──────────────────────────────────────────────────────────────────────
say "Orion O6 UAT — $(uname -r) — ${MINUTES} min per phase"
note "output: $OUTDIR"
dmesg_before

rc=0
case "$PHASE" in
cpu) phase_cpu || rc=1 ;;
gpu) phase_gpu || rc=1 ;;
npu) phase_npu || rc=1 ;;
all)
	phase_cpu || rc=1
	phase_gpu || rc=1
	phase_npu || rc=1
	;;
*)
	echo "unknown phase: $PHASE" >&2
	exit 64
	;;
esac

say "UAT complete"
note "artifacts in $OUTDIR"
exit "$rc"
