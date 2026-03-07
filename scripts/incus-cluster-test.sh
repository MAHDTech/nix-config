#!/usr/bin/env bash

# Usage: incus-cluster-test.sh \
#   --dataset PARENT_DS \
#   --count COUNT \
#   [--vol-size SIZE] \
#   [--zfs-create-options "-o compression=lz4 -o volblocksize=128k"] \
#   [--sparse] \
#   [--linstor-group NAME] \
#   [--linstor-size SIZE] \
#   [--linstor-prefix NAME] \
#   [--linstor-sleep SECONDS] \
#   [--zfs-only|--linstor-only|--skip-zfs|--skip-linstor]

# Defaults to mimic LINSTOR StorDriver/ZfscreateOptions
VOL_SIZE="1G" # ZFS zvol size
ZFS_CREATE_OPTS="-o compression=lz4 -o volblocksize=128k"
SPARSE_FLAG=""

# LINSTOR defaults
LINSTOR_GROUP="linstor"
LINSTOR_SIZE="1GiB" # LINSTOR volume size
LINSTOR_PREFIX="linstor-test-volume"
LINSTOR_SLEEP=30
LINSTOR_CONTROLLERS="10.10.200.11:3370"

# Test selection defaults
RUN_ZFS_TEST=1
RUN_LINSTOR_TEST=1

# Runtime state
TOTAL_START_TS=$(date +%s)
EXIT_CODE=0
ZFS_TEST_DS=""
ZVOL_NAMES=()
LINSTOR_RESOURCES=()

# Metrics
zfs_created_ok=0
zfs_created_fail=0
zfs_deleted_ok=0
zfs_deleted_fail=0
linstor_spawn_ok=0
linstor_spawn_fail=0
linstor_delete_ok=0
linstor_delete_fail=0

# Logging helpers
_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(_ts)] [$1] ${*:2}"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_err() { log ERROR "$@"; }
log_ok() { log OK "$@"; }

# Cleanup handler (always runs)
# shellcheck disable=SC2317,SC2329 # Called via trap; ShellCheck can't always detect indirect invocation
cleanup() {
	# Prevent recursive cleanup if already in progress
	[ -n "$__CLEANUP_RUNNING" ] && return
	__CLEANUP_RUNNING=1

	log_info "Starting cleanup"

	# Best-effort LINSTOR cleanup (delete any remaining resource-definitions we created)
	if [ ${#LINSTOR_RESOURCES[@]} -gt 0 ] && command -v linstor >/dev/null 2>&1; then
		for res in "${LINSTOR_RESOURCES[@]}"; do
			log_info "Cleanup: deleting LINSTOR resource-definition $res (best-effort)"
			if linstor --controllers "${LINSTOR_CONTROLLERS}" resource-definition delete "$res" >/dev/null 2>&1; then
				: # no counter updates in cleanup
			fi
		done
	fi

	# Best-effort ZFS cleanup
	if [ -n "$ZFS_TEST_DS" ]; then
		log_info "Cleanup: destroying ZFS test dataset $ZFS_TEST_DS recursively (best-effort)"
		zfs destroy -r "$ZFS_TEST_DS" >/dev/null 2>&1 || true
	fi

	log_info "Cleanup complete"
}
trap cleanup EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--dataset)
		PARENT_DS="$2"
		shift 2
		;;
	--count)
		COUNT="$2"
		shift 2
		;;
	--vol-size)
		VOL_SIZE="$2"
		shift 2
		;;
	--zfs-create-options)
		ZFS_CREATE_OPTS="$2"
		shift 2
		;;
	--sparse)
		SPARSE_FLAG="-s"
		shift 1
		;;
	--linstor-group)
		LINSTOR_GROUP="$2"
		shift 2
		;;
	--linstor-size)
		LINSTOR_SIZE="$2"
		shift 2
		;;
	--linstor-prefix)
		LINSTOR_PREFIX="$2"
		shift 2
		;;
	--linstor-sleep)
		LINSTOR_SLEEP="$2"
		shift 2
		;;
	--zfs-only)
		RUN_ZFS_TEST=1
		RUN_LINSTOR_TEST=0
		shift 1
		;;
	--linstor-only)
		RUN_ZFS_TEST=0
		RUN_LINSTOR_TEST=1
		shift 1
		;;
	--skip-zfs)
		RUN_ZFS_TEST=0
		shift 1
		;;
	--skip-linstor)
		RUN_LINSTOR_TEST=0
		shift 1
		;;
	*)
		log_err "Unknown option: $1"
		exit 2
		;;
	esac
done

if [ -z "$PARENT_DS" ] || [ -z "$COUNT" ]; then
	log_err "Missing parameters. Required: --dataset PARENT_DS --count COUNT"
	exit 2
fi

log_info "Starting tests: parent dataset=$PARENT_DS, count=$COUNT"

# Prepare ZFS test dataset with unique suffix
ZFS_TEST_DS="${PARENT_DS}/test-$(date +%s)"

# Prepare ZFS create options as array for safe passing
read -r -a ZFS_OPTS_ARRAY <<<"$ZFS_CREATE_OPTS"

run_zfs_test() {
	local start_ts end_ts
	start_ts=$(date +%s)

	# Ensure parent test dataset exists (filesystem dataset)
	if ! zfs list -H -o name "$ZFS_TEST_DS" >/dev/null 2>&1; then
		log_info "Creating parent dataset $ZFS_TEST_DS"
		if ! zfs create "$ZFS_TEST_DS"; then
			log_err "Failed to create $ZFS_TEST_DS"
			EXIT_CODE=1
			return
		fi
	else
		log_info "Parent dataset $ZFS_TEST_DS already exists"
	fi

	# Create COUNT child zvols
	for i in $(seq 1 "$COUNT"); do
		local child_vol="$ZFS_TEST_DS/vol-$i"
		log_info "Creating zvol $child_vol (size: $VOL_SIZE)"
		if zfs create -V "$VOL_SIZE" $SPARSE_FLAG "${ZFS_OPTS_ARRAY[@]}" "$child_vol"; then
			ZVOL_NAMES+=("$child_vol")
			zfs_created_ok=$((zfs_created_ok + 1))
		else
			log_err "Failed to create zvol $child_vol"
			EXIT_CODE=1
			zfs_created_fail=$((zfs_created_fail + 1))
		fi
	done

	# Delete COUNT child zvols one by one
	for child_vol in "${ZVOL_NAMES[@]}"; do
		log_info "Deleting zvol $child_vol"
		if zfs destroy "$child_vol"; then
			zfs_deleted_ok=$((zfs_deleted_ok + 1))
		else
			log_err "Failed to delete zvol $child_vol"
			EXIT_CODE=1
			zfs_deleted_fail=$((zfs_deleted_fail + 1))
		fi
	done

	# Final recursive cleanup of the test dataset
	log_info "Destroying test dataset $ZFS_TEST_DS recursively"
	if zfs destroy -r "$ZFS_TEST_DS"; then
		log_ok "Destroyed $ZFS_TEST_DS"
	else
		log_warn "Failed to destroy $ZFS_TEST_DS (will be retried in EXIT trap)"
		EXIT_CODE=1
	fi

	end_ts=$(date +%s)
	log_ok "ZFS test completed in $((end_ts - start_ts))s"
}

run_linstor_test() {
	# Check prerequisites
	if ! command -v linstor >/dev/null 2>&1; then
		log_warn "LINSTOR client not found; skipping LINSTOR test"
		return
	fi

	local start_ts end_ts
	start_ts=$(date +%s)

	# Optional: verify controller reachable and group exists
	if ! linstor --controllers "${LINSTOR_CONTROLLERS}" node list >/dev/null 2>&1; then
		log_err "LINSTOR controller not reachable; skipping LINSTOR test"
		EXIT_CODE=1
		return
	fi

	if ! linstor --controllers "${LINSTOR_CONTROLLERS}" resource-group list-properties "$LINSTOR_GROUP" >/dev/null 2>&1; then
		log_err "LINSTOR resource-group '$LINSTOR_GROUP' not found; skipping LINSTOR test"
		EXIT_CODE=1
		return
	fi

	local test_id
	test_id=$(date +%s)

	# Spawn COUNT resources
	for i in $(seq 1 "$COUNT"); do
		local res="${LINSTOR_PREFIX}-${test_id}-${i}"
		log_info "Spawning LINSTOR resource $res (group=$LINSTOR_GROUP, size=$LINSTOR_SIZE)"
		if linstor --controllers "${LINSTOR_CONTROLLERS}" resource-group spawn "$LINSTOR_GROUP" "$res" "$LINSTOR_SIZE"; then
			LINSTOR_RESOURCES+=("$res")
			linstor_spawn_ok=$((linstor_spawn_ok + 1))
		else
			log_err "Failed to spawn resource $res"
			EXIT_CODE=1
			linstor_spawn_fail=$((linstor_spawn_fail + 1))
		fi
		sleep "$LINSTOR_SLEEP"
	done

	# List status
	log_info "LINSTOR resource-definition list:"
	linstor --controllers "${LINSTOR_CONTROLLERS}" resource-definition list || true
	log_info "LINSTOR resource list:"
	linstor --controllers "${LINSTOR_CONTROLLERS}" resource list || true
	if command -v drbdadm >/dev/null 2>&1; then
		log_info "DRBD status:"
		drbdadm status || true
	fi

	# Delete resources
	for res in "${LINSTOR_RESOURCES[@]}"; do
		log_info "Deleting LINSTOR resource-definition $res"
		if linstor --controllers "${LINSTOR_CONTROLLERS}" resource-definition delete "$res"; then
			linstor_delete_ok=$((linstor_delete_ok + 1))
		else
			log_err "Failed to delete resource-definition $res"
			EXIT_CODE=1
			linstor_delete_fail=$((linstor_delete_fail + 1))
		fi
		sleep "$LINSTOR_SLEEP"
	done

	# Post-cleanup lists
	log_info "Post-cleanup LINSTOR resource-definition list:"
	linstor --controllers "${LINSTOR_CONTROLLERS}" resource-definition list || true
	log_info "Post-cleanup LINSTOR resource list:"
	linstor --controllers "${LINSTOR_CONTROLLERS}" resource list || true
	if command -v drbdadm >/dev/null 2>&1; then
		log_info "Post-cleanup DRBD status:"
		drbdadm status || true
	fi

	end_ts=$(date +%s)
	log_ok "LINSTOR test completed in $((end_ts - start_ts))s"
}

# Execute selected tests
if [ "$RUN_ZFS_TEST" -eq 1 ]; then
	log_info "Running ZFS zvol test (size=$VOL_SIZE, sparse=${SPARSE_FLAG:--}, opts=$ZFS_CREATE_OPTS)"
	run_zfs_test
fi

if [ "$RUN_LINSTOR_TEST" -eq 1 ]; then
	log_info "Running LINSTOR test (group=$LINSTOR_GROUP, size=$LINSTOR_SIZE, prefix=$LINSTOR_PREFIX, sleep=${LINSTOR_SLEEP}s)"
	run_linstor_test
fi

# Final summary
log_info "Summary:"
echo "- ZFS created:   ok=$zfs_created_ok fail=$zfs_created_fail"
echo "- ZFS deleted:   ok=$zfs_deleted_ok fail=$zfs_deleted_fail"
echo "- LINSTOR spawn: ok=$linstor_spawn_ok fail=$linstor_spawn_fail"
echo "- LINSTOR delete: ok=$linstor_delete_ok fail=$linstor_delete_fail"

total_elapsed=$(($(date +%s) - TOTAL_START_TS))
log_ok "All done in ${total_elapsed}s (exit=$EXIT_CODE)"

exit "$EXIT_CODE"
