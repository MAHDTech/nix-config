#!/usr/bin/env bash

clear

#set -x
set -euo pipefail

#########################
# Configuration
#########################

declare WHOAMI
WHOAMI="$(whoami)"
declare -a INOTIFY_RESULTS=()
declare -i TOTAL_WATCHES=0

#########################
# Functions
#########################

function log_msg() {
	local LEVEL="$1"
	local MESSAGE="$2"
	local COLOR=""

	case "${LEVEL}" in
	debug) COLOR="\033[32m" ;;
	info) COLOR="\033[32m" ;;
	warn) COLOR="\033[33m" ;;
	error) COLOR="\033[31m" ;;
	fatal) COLOR="\033[31m" ;;
	esac

	echo -e "${COLOR}[${LEVEL^^}]\033[0m ${MESSAGE}"
}

function get_process_info() {
	local PID="$1"
	ps -p "${PID}" -o pid=,comm=,args= --no-headers 2>/dev/null || echo ""
}

function count_inotify_watches() {
	local PID="$1"
	local COUNT=0

	[[ ! -d "/proc/${PID}/fdinfo" ]] && echo "0" && return

	# Count inotify watches
	while IFS= read -r line; do
		[[ $line =~ ^inotify ]] && COUNT=$((COUNT + 1))
	done < <(find "/proc/${PID}/fdinfo" -maxdepth 1 -type f -exec cat {} \; 2>/dev/null)

	echo "$COUNT"
}

format_process_line() {
	local COUNT="$1"
	local PID="$2"
	local PROCESS_INFO="$3"

	[[ -z $PROCESS_INFO ]] && return

	local COMM PARTS
	read -r PID COMM PARTS <<<"$(echo "$PROCESS_INFO" | awk '{print $1, $2, substr($0, index($0,$3))}')"

	# Truncate long command lines
	PARTS="${PARTS:0:50}"

	echo "${COUNT} ${PID} ${COMM} ${PARTS}"
}

#########################
# Main Processing
#########################

main() {
	log_msg "info" "Checking who is hogging all the inotify watches for ${WHOAMI}..."

	# Get all PIDs for current user
	mapfile -t PIDS < <(pgrep -u "${WHOAMI}" 2>/dev/null)

	[[ ${#PIDS[@]} -eq 0 ]] && {
		log_msg "error" "No processes found for user ${WHOAMI}"
		exit 1
	}

	log_msg "info" "Found ${#PIDS[@]} processes for user ${WHOAMI}"

	local -i PROCESSED=0
	local -i TOTAL_PROCESSES=${#PIDS[@]}

	# Process each PID
	for PID in "${PIDS[@]}"; do
		PROCESSED=$((PROCESSED + 1))

		# Progress indicator
		[[ $((PROCESSED % 10)) -eq 0 ]] &&
			log_msg "info" "Progress: ${PROCESSED}/${TOTAL_PROCESSES} processes checked..."

		# Skip invalid PIDs
		[[ ! $PID =~ ^[0-9]+$ ]] && continue
		[[ ! -d "/proc/${PID}" ]] && continue

		local WATCH_COUNT
		WATCH_COUNT=$(count_inotify_watches "$PID")

		[[ $WATCH_COUNT -eq 0 ]] && continue

		local PROCESS_INFO
		PROCESS_INFO=$(get_process_info "$PID")
		[[ -z $PROCESS_INFO ]] && continue

		local RESULT_LINE
		RESULT_LINE=$(format_process_line "$WATCH_COUNT" "$PID" "$PROCESS_INFO")

		INOTIFY_RESULTS+=("$RESULT_LINE")
		((TOTAL_WATCHES += WATCH_COUNT))
	done

	# Display results
	[[ ${#INOTIFY_RESULTS[@]} -eq 0 ]] && {
		log_msg "info" "No processes with inotify watches found"
		log_msg "info" "Total inotify watches: ${TOTAL_WATCHES}"
		return 0
	}

	# Header
	printf "\n%-6s %-8s %s\n" "PID" "Watches" "Command"
	printf "%-6s %-8s %s\n" "------" "--------" "----------------------------------------"

	# Sort and display
	printf '%s\n' "${INOTIFY_RESULTS[@]}" | sort -k1 -nr | while read -r line; do
		local count pid comm rest
		read -r count pid comm rest <<<"$line"
		printf "%-6s %-8s %s %s\n" "$pid" "$count" "$comm" "$rest"
	done

	printf "\n%-6s %-8s %s\n" "------" "--------" "----------------------------------------"
	log_msg "info" "Total inotify watches: ${TOTAL_WATCHES}"
}

# Run main function
main "$@"
