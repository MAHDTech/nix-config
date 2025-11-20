#!/usr/bin/env bash

check_os() {
	if ! grep -qE 'ID=(debian|ubuntu)' /etc/os-release; then
		echo "This script is only supported on Debian or Ubuntu."
		exit 1
	fi
}

install_deps() {
	echo "Installing dependencies..."
	sudo apt update
	sudo apt install -y stress-ng jq nvme-cli
}

get_cpu_temp() {
	local hwmon_dir=""
	# Find the AMD CPU hwmon (k10temp for AMD CPUs)
	for dir in /sys/class/hwmon/hwmon*/; do
		if [ -f "$dir/name" ] && [ "$(cat "$dir/name" 2>/dev/null)" = "k10temp" ]; then
			hwmon_dir="$dir"
			break
		fi
	done
	# Fallback to hwmon0 if not found
	if [ -z "$hwmon_dir" ]; then
		hwmon_dir="/sys/class/hwmon/hwmon0"
	fi
	local temp_milli
	temp_milli=$(cat "${hwmon_dir}/temp1_input" 2>/dev/null)
	if [ -z "$temp_milli" ] || [ "$temp_milli" -eq 0 ]; then
		echo "N/A"
		return
	fi
	printf "%.1f°C" "$((temp_milli / 1000))"
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
	local cpu_temp nvme_temps
	cpu_temp=$(get_cpu_temp)
	nvme_temps=$(get_nvme_temps)
	echo -ne "\rCPU: $cpu_temp NVMe: $nvme_temps     "
}

run_load_cpu() {
	local time="$1"
	echo "Starting CPU load test with stress-ng..."
	sudo stress-ng --cpu "$(nproc)" --timeout "${time}s" &
	local pid=$!
	trap 'sudo kill "$pid" 2>/dev/null; exit' SIGINT SIGTERM
	while sudo kill -0 "$pid" 2>/dev/null; do
		show_temps
		sleep 1
	done
	echo ""
}

run_load_io() {
	local time="$1"
	echo "Starting I/O (memory) load test with stress-ng..."
	sudo stress-ng --vm "$(nproc)" --vm-bytes 256M --timeout "${time}s" &
	local pid=$!
	trap 'sudo kill "$pid" 2>/dev/null; exit' SIGINT SIGTERM
	while sudo kill -0 "$pid" 2>/dev/null; do
		show_temps
		sleep 1
	done
	echo ""
}

run_load_disk() {
	local time="$1"
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
	while true; do
		show_temps
		sleep 1
		local now
		now=$(date +%s)
		if [ "$((now - start))" -ge "$time" ]; then
			break
		fi
	done
	sudo kill "${pids[@]}" 2>/dev/null
	echo ""
}

main() {
	check_os
	install_deps
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
