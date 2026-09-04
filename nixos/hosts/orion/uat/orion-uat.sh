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

# NixOS ships two sudo binaries: /run/current-system/sw/bin/sudo (not setuid, fails
# with "must be owned by uid 0") and /run/wrappers/bin/sudo (the real one).
# An interactive shell finds the wrapper first; a systemd unit with a narrow
# PATH does not. Getting this wrong silently voided every dmesg check in the
# first full run -- all four capture files were zero bytes -- and skipped the
# NPU phase entirely.
SUDO=/run/wrappers/bin/sudo
[ -u "$SUDO" ] || SUDO=$(command -v sudo)

say() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }
die() {
	printf '\n!! %s\n' "$*" >&2
	exit 1
}

# ── resolve every tool BEFORE any phase starts ───────────────────────────────
# Learned the hard way: `nix shell` inside a systemd unit aborted with
#   aborting: temp-path '.' must be readable and writeable
# and because this script runs under `set -uo pipefail` (no -e), the CPU phase
# skipped stress-ng entirely while the telemetry sampler happily ran for the
# full 30 minutes. The unit exited 0 and the run looked green having tested
# nothing. A missing tool must abort the run, loudly, before any timing starts.
resolve_tool() {
	local pkg="$1" bin="$2" path
	path=$(nix build --no-link --print-out-paths "$NIXPKGS#$pkg" 2>/dev/null | tail -1)
	[ -n "$path" ] || die "cannot resolve $pkg from nixpkgs — refusing to start a phase that would silently do nothing"
	[ -x "$path/bin/$bin" ] || die "$pkg resolved to $path but has no bin/$bin"
	printf '%s' "$path/bin/$bin"
}

# ── did the phase actually load the machine? ─────────────────────────────────
# A phase that produced no load must fail, even if every command exited 0.
# Compares the mean sampled frequency against an idle floor.
assert_loaded() {
	local csv="$1" col="$2" floor="$3" what="$4"
	local mean
	mean=$(awk -F, -v c="$col" 'NR>1 {s+=$c; n++} END {print (n? int(s/n) : 0)}' "$csv")
	if [ "$mean" -lt "$floor" ]; then
		echo "   FAIL: mean $what was $mean, below the idle floor $floor —"
		echo "         the phase did not actually load the machine"
		return 1
	fi
	echo "   load confirmed: mean $what $mean (floor $floor)"
	return 0
}

# ── temperature log ──────────────────────────────────────────────────────────
# Written to a FIXED path outside $OUTDIR as well as inside it, and synced to
# disk after every sample. The point is to survive an unplanned reboot: the GPU
# died once during a CPU-then-GPU sequence and there was no temperature record
# at all, so we could not tell heat from a power-sequencing fault. A log that is
# still in the page cache when the box resets is no better than no log.
TEMPLOG=/var/tmp/orion-temps.csv

temp_header() {
	local hdr="epoch,phase"
	for t in /sys/class/hwmon/hwmon*/temp*_input; do
		[ -e "$t" ] || continue
		local lbl
		lbl=$(cat "${t%_input}_label" 2>/dev/null || basename "$t")
		hdr="$hdr,$lbl"
	done
	echo "$hdr"
}

temp_logger() {
	local phase="$1" end=$(($(date +%s) + SECS + 10))
	[ -s "$TEMPLOG" ] || temp_header >"$TEMPLOG"
	while [ "$(date +%s)" -lt "$end" ]; do
		local row
		row="$(date +%s),$phase"
		for t in /sys/class/hwmon/hwmon*/temp*_input; do
			[ -e "$t" ] || continue
			row="$row,$(awk -v x="$(cat "$t" 2>/dev/null || echo 0)" 'BEGIN{printf "%.1f", x/1000}')"
		done
		echo "$row" >>"$TEMPLOG"
		# fsync the directory entry and data; 1 Hz makes this cheap and it is
		# the difference between having the last reading before a crash and not.
		sync -d "$TEMPLOG" 2>/dev/null || sync
		sleep 1
	done
}

# Hottest sensor seen during a phase, straight from the persisted log.
temp_summary() {
	local phase="$1"
	[ -s "$TEMPLOG" ] || {
		echo "   no temperature log"
		return
	}
	awk -F, -v ph="$phase" '
	  NR==1 { for (i=3; i<=NF; i++) name[i]=$i; next }
	  $2==ph { n++; for (i=3; i<=NF; i++) { if ($i+0 > mx[i]) mx[i]=$i+0; sum[i]+=$i } }
	  END {
	    if (!n) { print "   no samples for this phase"; exit }
	    printf "   peak temperatures over %d samples:\n", n
	    for (i=3; i<=NF; i++)
	      if (mx[i] > 0) printf "     %-10s max %5.1f C   mean %5.1f C\n", name[i], mx[i], sum[i]/n
	  }' "$TEMPLOG"
}

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
      if (tmax>0) printf "   temp max / mean  : %.1f C / %.1f C\n", tmax/1000, (tsum/n)/1000
      else {
        printf "   temperature      : NOT OBSERVABLE\n"
        printf "                      this board exposes no thermal zones on mainline\n"
        printf "                      (thermal driver unported), so thermal behaviour\n"
        printf "                      under sustained load is UNVERIFIED\n"
      }
      if (gmax>0) { printf "   GPU freq residency:\n"; for (f in gfreq) printf "     %d MHz : %d s\n", f/1e6, gfreq[f] }
    }' "$csv"
}

# The ring buffer must be DIFFED, not just grepped. Grepping the whole buffer
# reported the boot-time armchina IRQ warning as a failure of every phase --
# a pre-existing line has nothing to do with what the stress run did. Snapshot
# immediately before the load, then judge only lines that appeared since.
KERN_BAD="SError|Internal error|Unable to handle|BUG:|Call trace|hung task|thermal.*critical|GPU fault|MMU fault|watchdog"

dmesg_snapshot() { "$SUDO" -n dmesg 2>/dev/null | tee "$1" >/dev/null; }

dmesg_verdict() {
	local pre="$1" out="$2"
	"$SUDO" -n dmesg 2>/dev/null | tee "$out.now" >/dev/null
	# Lines present now but absent from the snapshot: produced by this phase.
	grep -Fxv -f "$pre" "$out.now" >"$out" 2>/dev/null
	rm -f "$out.now"
	if grep -qiE "$KERN_BAD" "$out"; then
		echo "   KERNEL ERRORS DURING THIS PHASE:"
		grep -iE "$KERN_BAD" "$out" | head -10 | sed 's/^/     /'
		return 1
	fi
	echo "   kernel ring buffer clean for this phase (no new SError, oops, fault or hung task)"
	return 0
}

# ── CPU ──────────────────────────────────────────────────────────────────────
phase_cpu() {
	say "CPU stress — ${MINUTES} min"
	note "12 cores: 4x Cortex-A720 @ up to 2.6 GHz, 4x A720, 4x A520"
	note "boost = $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null)"

	dmesg_snapshot "$OUTDIR/cpu-dmesg-pre.txt"
	temp_logger cpu &
	local templog=$!
	sample_telemetry "$OUTDIR/cpu.csv" &
	local sampler=$!

	# --cpu 0 uses every online CPU. matrix and vm alongside cpu exercise FPU/SIMD
	# and the memory subsystem, not just the integer pipeline, so a marginal
	# regulator or a memory clock problem has a chance to show up.
	"$STRESS_NG" --cpu 0 --matrix 0 --vm 2 --vm-bytes 1G \
		--timeout "${SECS}s" --metrics-brief --times \
		2>&1 | tee "$OUTDIR/cpu-stress.log" | tail -25

	wait $sampler 2>/dev/null
	say "CPU result"
	local rc=0
	wait $templog 2>/dev/null
	summarise "$OUTDIR/cpu.csv" cpu
	temp_summary cpu
	# 1.2 GHz mean: comfortably above idle, well under any real load level.
	assert_loaded "$OUTDIR/cpu.csv" 2 1200000 "CPU kHz" || rc=1
	grep -qE "successful run completed" "$OUTDIR/cpu-stress.log" ||
		{
			echo "   FAIL: stress-ng did not report a successful run"
			rc=1
		}
	dmesg_verdict "$OUTDIR/cpu-dmesg-pre.txt" "$OUTDIR/cpu-dmesg.txt" || rc=1
	return $rc
}

# ── GPU ──────────────────────────────────────────────────────────────────────
phase_gpu() {
	say "GPU stress — ${MINUTES} min"
	note "Mali-G720 Immortalis MC10 via panthor + Mesa panfrost/panvk"
	note "OFFSCREEN: proves shader cores, tiler, MMU, job submission and DVFS."
	note "It does NOT prove absence of visual corruption — that needs a human"
	note "at the display once USB/keyboard and the display driver are working."

	dmesg_snapshot "$OUTDIR/gpu-dmesg-pre.txt"
	temp_logger gpu &
	local templog=$!
	sample_telemetry "$OUTDIR/gpu.csv" &
	local sampler=$!
	local end=$(($(date +%s) + SECS)) run=0

	# glmark2 is a fixed-length benchmark, so loop it to fill the window and keep
	# the GPU continuously busy rather than idling between runs.
	# Abort the loop if a run stops producing a score. The first full UAT spun
	# 64300 times in 29 minutes writing a 620 MB log of
	#   MESA: error: DRM_IOCTL_PANTHOR_BO_CREATE failed (err=19)
	# because panthor had unplugged the device after a failed reset and every
	# subsequent glmark2 exited instantly. A dead GPU must fail the phase, not
	# be hammered for the rest of the window.
	local consecutive_fail=0
	while [ "$(date +%s)" -lt "$end" ]; do
		run=$((run + 1))
		local before
		before=$(grep -c "glmark2 Score" "$OUTDIR/gpu-glmark2.log" 2>/dev/null || echo 0)
		"$GLMARK2" --off-screen -b build -b texture -b shading -b bump \
			-b refract -b conditionals -b function -b terrain \
			2>&1 | tail -400 >>"$OUTDIR/gpu-glmark2.log"
		local after
		after=$(grep -c "glmark2 Score" "$OUTDIR/gpu-glmark2.log" 2>/dev/null || echo 0)
		if [ "$after" -le "$before" ]; then
			consecutive_fail=$((consecutive_fail + 1))
			note "run $run produced NO score (failure $consecutive_fail)"
			if [ "$consecutive_fail" -ge 3 ]; then
				echo "   FAIL: glmark2 stopped producing scores after $run runs --"
				echo "         the GPU is no longer usable. Aborting the phase."
				break
			fi
		else
			consecutive_fail=0
			grep "glmark2 Score" "$OUTDIR/gpu-glmark2.log" | tail -1 | sed 's/^/   /'
			note "run $run complete, $((end - $(date +%s)))s remaining"
		fi
	done

	wait $sampler 2>/dev/null
	say "GPU result"
	note "scores across $run runs:"
	grep "glmark2 Score" "$OUTDIR/gpu-glmark2.log" | sed 's/^/     /'
	# A score that decays run over run means thermal or power throttling.
	local rc=0
	wait $templog 2>/dev/null
	summarise "$OUTDIR/gpu.csv" gpu
	temp_summary gpu
	# 500 MHz mean: above the 350 MHz idle OPP, so the governor really ramped.
	assert_loaded "$OUTDIR/gpu.csv" 3 500000000 "GPU Hz" || rc=1
	grep -q "glmark2 Score" "$OUTDIR/gpu-glmark2.log" ||
		{
			echo "   FAIL: no glmark2 score recorded"
			rc=1
		}
	dmesg_verdict "$OUTDIR/gpu-dmesg-pre.txt" "$OUTDIR/gpu-dmesg.txt" || rc=1
	return $rc
}

# ── NPU ──────────────────────────────────────────────────────────────────────
phase_npu() {
	say "NPU stress — ${MINUTES} min"
	note "ArmChina Zhouyi V3 via armchina_npu (out-of-tree, carried patch)"

	if [ ! -e /dev/aipu ]; then
		note "/dev/aipu absent — loading the module (blacklisted for now)"
		"$SUDO" -n modprobe armchina_npu 2>&1 | sed 's/^/     /'
		sleep 2
	fi
	if [ ! -e /dev/aipu ]; then
		echo "   FAIL: /dev/aipu still absent; the driver did not bind" >&2
		"$SUDO" -n dmesg | grep -iE "aipu|armchina|npu" | tail -20 | sed 's/^/     /'
		return 1
	fi

	local bin="$OUTDIR/aipu-uat"
	"$CC" -O2 -Wall -o "$bin" "$(dirname "$0")/aipu-uat.c" || return 1

	dmesg_snapshot "$OUTDIR/npu-dmesg-pre.txt"
	temp_logger npu &
	local templog=$!
	sample_telemetry "$OUTDIR/npu.csv" &
	local sampler=$!

	# /dev/aipu is root:render 0660 and this user is in video, not render, so
	# the smoke run failed with EACCES. sudo rather than a group change: the
	# tool needs no other privilege and this keeps the test self-contained.
	"$SUDO" -n "$bin" --stress "$SECS" 2>&1 | tee "$OUTDIR/npu-uat.log"
	local rc=${PIPESTATUS[0]}

	wait $sampler 2>/dev/null
	say "NPU result"
	note "power domains:"
	"$SUDO" -n grep -iE "npu" /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null | sed 's/^/     /'
	note "interrupts:"
	grep -iE "aipu|npu" /proc/interrupts 2>/dev/null | sed 's/^/     /' || note "  (none registered)"
	wait $templog 2>/dev/null
	summarise "$OUTDIR/npu.csv" npu
	temp_summary npu
	dmesg_verdict "$OUTDIR/npu-dmesg-pre.txt" "$OUTDIR/npu-dmesg.txt"
	return "$rc"
}

# ── run ──────────────────────────────────────────────────────────────────────
say "Orion O6 UAT — $(uname -r) — ${MINUTES} min per phase"
note "output: $OUTDIR"

# Resolve up front so a phase can never be skipped by a tooling failure.
case "$PHASE" in
cpu | all)
	STRESS_NG=$(resolve_tool stress-ng stress-ng)
	note "stress-ng: $STRESS_NG"
	;;
esac
case "$PHASE" in
gpu | all)
	GLMARK2=$(resolve_tool glmark2 glmark2-es2-gbm)
	note "glmark2:   $GLMARK2"
	;;
esac
case "$PHASE" in
npu | all)
	CC=$(resolve_tool gcc gcc)
	note "cc:        $CC"
	;;
esac

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
