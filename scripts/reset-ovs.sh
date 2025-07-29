#!/usr/bin/env bash

clear
set -euo pipefail

#########################
# Functions
#########################

function msg() {
	local LOG_LEVEL=$1
	local MESSAGE=$2
	local TIMESTAMP
	TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)

	case $LOG_LEVEL in
	DEBUG)
		echo -e "\033[34m[${TIMESTAMP}] [DEBUG] ${MESSAGE}\033[0m"
		;;
	INFO)
		echo -e "\033[32m[${TIMESTAMP}] [INFO] ${MESSAGE}\033[0m"
		;;
	WARNING)
		echo -e "\033[33m[${TIMESTAMP}] [WARNING] ${MESSAGE}\033[0m"
		;;
	ERROR)
		echo -e "\033[31m[${TIMESTAMP}] [ERROR] ${MESSAGE}\033[0m"
		;;
	*)
		echo -e "\033[37m[${TIMESTAMP}] [UNKNOWN] ${MESSAGE}\033[0m"
		;;
	esac
	return 0
}

function show_warning() {
	cat <<-EOF
		==================================================
		Open vSwitch Complete Reset Script
		==================================================

		⚠️  WARNING: This will completely reset Open vSwitch configuration!
		   - All bridges will be deleted
		   - All ports will be removed
		   - All flows will be cleared
		   - OVS database will be reset

	EOF
	return 0
}

function confirm_reset() {
	local confirm
	read -rp "Do you want to continue? (yes/no): " confirm

	if [ "$confirm" != "yes" ]; then
		msg "INFO" "Operation cancelled."
		return 1
	fi
}

function stop_dependent_services() {
	msg "INFO" "Stopping services that depend on OVS..."
	sudo systemctl stop incus-preseed.service || true
	sudo systemctl stop incus.service || true
	sudo systemctl stop ovn-controller.service || true
	sudo systemctl stop ovn-northd.service || true
	return 0
}

function show_current_config() {
	msg "INFO" "Current OVS configuration before reset:"
	sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock show || msg "WARNING" "Could not show OVS config"
	return 0
}

function remove_all_bridges() {
	msg "INFO" "Removing all bridges..."
	for bridge in $(sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list-br 2>/dev/null || true); do
		msg "DEBUG" "Deleting bridge: $bridge"
		sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock --if-exists del-br "$bridge"
	done
	return 0
}

function stop_ovs_services() {
	msg "INFO" "Stopping OVS services..."
	sudo systemctl stop ovs-vswitchd.service
	return 0
}

function clear_ovs_database() {
	msg "INFO" "Clearing OVS database..."
	sudo rm -f /var/lib/openvswitch/conf.db*
	sudo rm -f /etc/openvswitch/conf.db*
	return 0
}

function recreate_ovs_database() {
	msg "INFO" "Recreating OVS database..."

	# Ensure the directory exists
	sudo mkdir -p /var/lib/openvswitch

	local schema_path
	schema_path=$(find /nix/store -name "vswitch.ovsschema" -path "*/share/openvswitch/*" 2>/dev/null | head -1)

	if [ -z "$schema_path" ]; then
		msg "ERROR" "Could not find OVS schema file"
		return 1
	fi

	msg "DEBUG" "Using schema: $schema_path"
	sudo ovsdb-tool create /var/lib/openvswitch/conf.db "$schema_path" || {
		msg "ERROR" "Failed to create OVS database"
		return 1
	}
	return 0
}

function start_ovs_services() {
	msg "INFO" "Starting OVS services..."
	sudo systemctl start ovs-vswitchd.service
	return 0
}

function wait_for_ovs_ready() {
	msg "INFO" "Waiting for OVS to be ready..."
	for i in {1..30}; do
		if sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock show >/dev/null 2>&1; then
			msg "INFO" "OVS is ready!"
			break
		fi
		msg "DEBUG" "Waiting... ($i/30)"
		sleep 2
	done
	return 0
}

function verify_ovs_reset() {
	msg "INFO" "Verifying OVS reset:"
	sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock show
	return 0
}

function start_dependent_services() {
	msg "INFO" "Starting dependent services..."
	sudo systemctl start ovn-controller.service
	sudo systemctl start incus.service
	return 0
}

function show_next_steps() {
	cat <<-EOF
		==================================================
		OVS Reset Complete!
		==================================================

		Next steps:
		1. Restart Incus preseed to recreate networks:

		   sudo systemctl restart incus-preseed.service

		2. Check network status:

		   incus network list
		   sudo ovs-vsctl show

		3. Manually add bond0 to incusbr0 if needed:

		   sudo ovs-vsctl add-port incusbr0 bond0

	EOF
	return 0
}

#########################
# Main
#########################

show_warning || {
	msg "ERROR" "Failed to show warning"
	exit 1
}

confirm_reset || {
	msg "ERROR" "Failed to confirm reset"
	exit 1
}

stop_dependent_services || {
	msg "ERROR" "Failed to stop dependent services"
	exit 1
}

show_current_config || {
	msg "ERROR" "Failed to show current config"
	exit 1
}

remove_all_bridges || {
	msg "ERROR" "Failed to remove all bridges"
	exit 1
}

stop_ovs_services || {
	msg "ERROR" "Failed to stop OVS services"
	exit 1
}

clear_ovs_database || {
	msg "ERROR" "Failed to clear OVS database"
	exit 1
}

recreate_ovs_database || {
	msg "ERROR" "Failed to recreate OVS database"
	exit 1
}

start_ovs_services || {
	msg "ERROR" "Failed to start OVS services"
	exit 1
}

wait_for_ovs_ready || {
	msg "ERROR" "Failed to wait for OVS to be ready"
	exit 1
}

verify_ovs_reset || {
	msg "ERROR" "Failed to verify OVS reset"
	exit 1
}

start_dependent_services || {
	msg "ERROR" "Failed to start dependent services"
	exit 1
}

show_next_steps || {
	msg "ERROR" "Failed to show next steps"
	exit 1
}
