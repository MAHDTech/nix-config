#!/usr/bin/env bash

##################################################
# Declarations
##################################################

# ANSI color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

declare -A max_temps
start_time=""

##################################################
# Functions
##################################################

cleanup() {
	# Kill any running background processes from the test
	sudo pkill -f "stress-ng.*--timeout" 2>/dev/null || true
	sudo pkill -f "dd.*bs=4M.*iflag=direct" 2>/dev/null || true
}

check_os() {
	if ! grep -qE 'ID=(debian|ubuntu)' /etc/os-release; then
		echo "This script is only supported on Debian or Ubuntu."
		exit 1
	fi
}

install_deps() {
	echo "Installing dependencies..."
	sudo apt update
	sudo apt install -y stress-ng jq nvme-cli htop btop smartmontools bc
}

update_max() {
	local key="$1"
	local current="$2"
	if [ "$current" = "N/A" ]; then
		return
	fi
	local num
	num=$(echo "$current" | sed 's/°C//' | sed 's/%$//')
	if [ -z "${max_temps[$key]}" ] || (($(echo "$num > ${max_temps[$key]}" | bc -l 2>/dev/null))); then
		max_temps[$key]="$num"
	fi
}

get_cpu_temp() {
	local temp_milli=""

	# First, try k10temp hwmon for AMD Ryzen CPUs.
	for dir in /sys/class/hwmon/hwmon*/; do
		if [ -f "$dir/name" ] && [ "$(cat "$dir/name" 2>/dev/null)" = "k10temp" ]; then
			temp_milli=$(cat "$dir/temp1_input" 2>/dev/null)
			if [ -n "$temp_milli" ] && [ "$temp_milli" -gt 0 ]; then
				local temp
				temp=$(printf "%.1f°C" "$((temp_milli / 1000))")
				update_max "CPU" "$temp"
				echo "$temp"
				return
			fi
		fi
	done

	# Next, try hwmon0 temp1_input for the AMD Ryzen Laptop CPUs that don't have k10temp.
	if [ -f "/sys/class/hwmon/hwmon0/temp1_input" ]; then
		temp_milli=$(cat "/sys/class/hwmon/hwmon0/temp1_input" 2>/dev/null)
		if [ -n "$temp_milli" ] && [ "$temp_milli" -gt 0 ]; then
			local temp
			temp=$(printf "%.1f°C" "$((temp_milli / 1000))")
			update_max "CPU" "$temp"
			echo "$temp"
			return
		fi
	fi

	# TODO: More specirfic implementations go here...

	# Last resort: try other hwmons as a default catch all.
	for dir in /sys/class/hwmon/hwmon*/; do
		if [ ! -f "$dir/name" ] || [ "$(cat "$dir/name" 2>/dev/null)" != "k10temp" ]; then
			if [ -f "$dir/temp1_input" ]; then
				temp_milli=$(cat "$dir/temp1_input" 2>/dev/null)
				if [ -n "$temp_milli" ] && [ "$temp_milli" -gt 0 ]; then
					local temp
					temp=$(printf "%.1f°C" "$((temp_milli / 1000))")
					update_max "CPU" "$temp"
					echo "$temp"
					return
				fi
			fi
		fi
	done

	# If all failed, N/A
	echo "N/A"
}

get_nvme_temps() {
	local temps=""
	local devs
	devs=$(ls /dev/nvme*n1 2>/dev/null)
	for dev in $devs; do
		if [ -b "$dev" ]; then
			local json
			if json=$(sudo nvme smart-log "$dev" --output json 2>/dev/null) && [ -n "$json" ]; then
				local temp_k
				temp_k=$(echo "$json" | jq -r '.temperature // empty')
				if [ -n "$temp_k" ] && [ "$temp_k" != "null" ]; then
					local temp_c=$((temp_k - 273))
					temps="$temps $(basename "$dev"): ${temp_c}°C"
				fi
				local temp1 temp2
				temp1=$(echo "$json" | jq -r '.temperature_sensor_1 // empty')
				temp2=$(echo "$json" | jq -r '.temperature_sensor_2 // empty')
				if [ -n "$temp1" ] && [ "$temp1" != "null" ]; then
					temps="$temps $(basename "$dev")_s1: $((temp1 - 273))°C"
				fi
				if [ -n "$temp2" ] && [ "$temp2" != "null" ]; then
					temps="$temps $(basename "$dev")_s2: $((temp2 - 273))°C"
				fi
			fi
		fi
	done
	echo "$temps"
}

show_temps() {
	local remaining="$1"
	local cpu_temp load_avg
	cpu_temp=$(get_cpu_temp)
	load_avg=$(awk '{print $1}' /proc/loadavg)
	update_max "CPU" "$cpu_temp"
	update_max "Load" "$load_avg"
	local remaining_minutes=$((remaining / 60))
	local remaining_seconds=$((remaining % 60))
	local nvme_output=""
	local devs
	devs=$(ls /dev/nvme*n1 2>/dev/null)
	for dev in $devs; do
		if [ -b "$dev" ]; then
			local json
			if json=$(sudo nvme smart-log "$dev" --output json 2>/dev/null) && [ -n "$json" ]; then
				local temp_k temp1 temp2
				temp_k=$(echo "$json" | jq -r '.temperature // empty')
				if [ -n "$temp_k" ] && [ "$temp_k" != "null" ]; then
					local temp_c=$((temp_k - 273))
					nvme_output="${nvme_output}${BLUE}NVMe $(basename "$dev") Temp:${NC} ${temp_c}°C\n"
					update_max "nvme$(basename "$dev")" "${temp_c}°C"
				fi
				temp1=$(echo "$json" | jq -r '.temperature_sensor_1 // empty')
				temp2=$(echo "$json" | jq -r '.temperature_sensor_2 // empty')
				if [ -n "$temp1" ] && [ "$temp1" != "null" ]; then
					local temp1_c=$((temp1 - 273))
					nvme_output="${nvme_output}${BLUE}NVMe $(basename "$dev") Temp S1:${NC} ${temp1_c}°C\n"
					update_max "nvme$(basename "$dev")_s1" "${temp1_c}°C"
				fi
				if [ -n "$temp2" ] && [ "$temp2" != "null" ]; then
					local temp2_c=$((temp2 - 273))
					nvme_output="${nvme_output}${BLUE}NVMe $(basename "$dev") Temp S2:${NC} ${temp2_c}°C\n"
					update_max "nvme$(basename "$dev")_s2" "${temp2_c}°C"
				fi
			fi
		fi
	done
	local smart_output=""
	devs=$(ls /dev/sd* 2>/dev/null)
	for dev in $devs; do
		if [ -b "$dev" ]; then
			local actual_temp="N/A"
			local temp
			temp=$(sudo smartctl -A "$dev" 2>/dev/null | awk '/Temperature_Celsius/{print $10}')
			if [ -n "$temp" ] && [ "$temp" != "-" ]; then
				actual_temp="$temp°C"
			fi
			smart_output="${smart_output}${BLUE}Drive $(basename "$dev") Temp:${NC} $actual_temp\n"
			update_max "$(basename "$dev")" "$actual_temp"
		fi
	done
	clear
	echo -e "################################"
	echo -e "BURN IN TEST IS RUNNING"
	echo -e "TIME REMAINING: ${remaining_minutes}m ${remaining_seconds}s"
	echo -e "################################"
	echo -e ""
	echo -e "##### SYSTEM #####"
	echo -e ""
	echo -e "${GREEN}CPU Temp:${NC} $cpu_temp"
	echo -e "${RED}System Load:${NC} $load_avg"
	echo -e ""
	echo -e "##### NVMe #####"
	echo -e ""
	if [ -n "$nvme_output" ]; then echo -e "$nvme_output"; else echo -e "N/A"; fi
	echo -e "##### S.M.A.R.T #####"
	echo -e ""
	if [ -n "$smart_output" ]; then echo -e "$smart_output"; else echo -e "N/A"; fi
	echo -e "#################################"
}

print_final_summary() {
	local time_taken=$1
	clear
	echo -e "################################"
	echo -e "BURN IN TEST RESULTS"
	echo -e "TIME TAKEN: ${time_taken}m ${time_taken}s"
	echo -e "################################"
	echo -e ""
	echo -e "##### SYSTEM (Max values) #####"
	echo -e ""
	echo -e "CPU Temp: ${max_temps[CPU]}°C"
	echo -e "System Load: ${max_temps[Load]}"
	echo -e ""
	echo -e "##### NVMe (Max values) #####"
	echo -e ""
	for key in "${!max_temps[@]}"; do
		case "$key" in
		nvme*)
			echo "NVMe $key Temp: ${max_temps[$key]}"
			;;
		esac
	done
	echo -e ""
	echo -e "##### S.M.A.R.T (Max values) #####"
	echo -e ""
	for key in "${!max_temps[@]}"; do
		case "$key" in
		sd*)
			echo "Drive $key Temp: ${max_temps[$key]}"
			;;
		esac
	done
}

run_load_cpu() {
	local time="$1"
	local start
	start=$(date +%s)
	start_time=$start
	echo "Starting CPU load test with stress-ng..."
	sudo stress-ng --cpu "$(nproc)" --timeout "${time}s" &
	local pid=$!
	trap 'sudo kill "$pid" 2>/dev/null; exit' SIGINT SIGTERM
	while sudo kill -0 "$pid" 2>/dev/null; do
		local now
		now=$(date +%s)
		local elapsed=$((now - start))
		local remaining=$((time - elapsed))
		[ "$remaining" -lt 0 ] && remaining=0
		show_temps "$remaining"
		sleep 1
	done
	show_temps 0
	local end_time
	end_time=$(date +%s)
	local total_time=$((end_time - start_time))
	local minutes=$((total_time / 60))
	local seconds=$((total_time % 60))
	print_final_summary "${minutes}m ${seconds}s"
	echo ""
}

run_load_io() {
	local time="$1"
	local start
	start=$(date +%s)
	start_time=$start
	echo "Starting I/O (memory) load test with stress-ng..."
	sudo stress-ng --vm "$(nproc)" --vm-bytes 256M --timeout "${time}s" &
	local pid=$!
	trap 'sudo kill "$pid" 2>/dev/null; exit' SIGINT SIGTERM
	while sudo kill -0 "$pid" 2>/dev/null; do
		local now
		now=$(date +%s)
		local elapsed=$((now - start))
		local remaining=$((time - elapsed))
		[ "$remaining" -lt 0 ] && remaining=0
		show_temps "$remaining"
		sleep 1
	done
	show_temps 0
	local end_time
	end_time=$(date +%s)
	local total_time=$((end_time - start_time))
	local minutes=$((total_time / 60))
	local seconds=$((total_time % 60))
	print_final_summary "${minutes}m ${seconds}s"
	echo ""
}

run_load_disk() {
	local time="$1"
	local start
	start=$(date +%s)
	start_time=$start
	echo "Starting disk load test by reading from NVMe devices..."
	echo "Warning: This will read large amounts of data from disks. Ensure they are not system disks."
	local pids=()
	local devs
	devs=$(ls /dev/nvme*n1 2>/dev/null)
	for dev in $devs; do
		if [ -b "$dev" ]; then
			# Run dd in a loop to continuously read
			(while true; do sudo dd if="$dev" of=/dev/null bs=4M iflag=direct; done) &
			pids+=($!)
		fi
	done
	if [ "${#pids[@]}" -eq 0 ]; then
		echo "No NVMe devices found."
		return
	fi
	trap 'sudo kill "${pids[@]}" 2>/dev/null; exit' SIGINT SIGTERM
	local start
	start=$(date +%s)
	while [[ ${#pids[@]} -gt 0 ]]; do
		local now
		now=$(date +%s)
		local elapsed=$((now - start))
		local remaining=$((time - elapsed))
		[ "$remaining" -lt 0 ] && remaining=0
		show_temps "$remaining"
		sleep 1
		if [ "$elapsed" -ge "$time" ]; then
			break
		fi
		# Filter out dead pids
		local live_pids=()
		for p in "${pids[@]}"; do
			if sudo kill -0 "$p" 2>/dev/null; then
				live_pids+=("$p")
			fi
		done
		pids=("${live_pids[@]}")
	done
	sudo kill "${pids[@]}" 2>/dev/null
	local end_time
	end_time=$(date +%s)
	local total_time=$((end_time - start_time))
	local minutes=$((total_time / 60))
	local seconds=$((total_time % 60))
	print_final_summary "${minutes}m ${seconds}s"
	echo ""
}

main() {
	check_os
	install_deps
	trap cleanup INT TERM
	local time=600
	local type="cpu"
	while [ $# -gt 0 ]; do
		case $1 in
		--time)
			time="$2"
			shift 2
			;;
		--type)
			type="$2"
			shift 2
			;;
		*)
			echo "Unknown option: $1"
			echo "Usage: $0 [--time seconds] [--type cpu|io|disk]"
			exit 1
			;;
		esac
	done
	if ! [[ $time =~ ^[0-9]+$ ]]; then
		echo "Time must be a positive integer."
		exit 1
	fi
	echo "Starting burn-in test: type=$type, time=${time}s"
	case "$type" in
	cpu)
		run_load_cpu "$time"
		;;
	io)
		run_load_io "$time"
		;;
	disk)
		run_load_disk "$time"
		;;
	*)
		echo "Invalid type: $type. Valid options: cpu, io, disk"
		exit 1
		;;
	esac
	echo "Burn-in test completed."
}

main "$@"
