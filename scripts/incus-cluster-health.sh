#!/usr/bin/env bash

set -euo pipefail

##################################################
# Variables
##################################################

# Service names to check
declare -r SERVICES=(
	"incus.service"
	"incus-preseed.service"
	"ovn-controller.service"
	"ovn-central.service"
	"ovn-southbound-db.service"
	"ovn-northbound-db.service"
)

# OVN database socket paths
declare -r OVN_NB_SOCKET="/var/run/ovn/ovnnb_db.sock"
declare -r OVN_SB_SOCKET="/var/run/ovn/ovnsb_db.sock"

# Timeout for OVN commands
declare -r OVN_TIMEOUT=10

##################################################
# Functions
##################################################

function log() {
	local LOG_LEVEL=$1
	local MESSAGE=$2
	local TIMESTAMP
	TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

	case $LOG_LEVEL in
	DEBUG)
		echo -e "\033[34m[${TIMESTAMP}] [DEBUG] ${MESSAGE}\033[0m"
		;;
	INFO)
		echo -e "\033[32m[${TIMESTAMP}] [INFO] ${MESSAGE}\033[0m"
		;;
	WARN)
		echo -e "\033[33m[${TIMESTAMP}] [WARN] ${MESSAGE}\033[0m"
		;;
	ERROR)
		echo -e "\033[31m[${TIMESTAMP}] [ERROR] ${MESSAGE}\033[0m"
		;;
	*)
		echo -e "\033[37m[${TIMESTAMP}] [UNKNOWN] ${MESSAGE}\033[0m"
		;;
	esac
}

function check_systemd_service() {
	local SERVICE=$1
	local STATUS
	local ENABLED
	local ACTIVE_STATE
	local SUB_STATE

	log "INFO" "Checking systemd service: $SERVICE"

	# Get service status information
	if STATUS=$(sudo systemctl show "$SERVICE" --property=ActiveState,SubState,UnitFileState 2>/dev/null); then
		ACTIVE_STATE=$(echo "$STATUS" | grep "ActiveState=" | cut -d'=' -f2)
		SUB_STATE=$(echo "$STATUS" | grep "SubState=" | cut -d'=' -f2)
		ENABLED=$(echo "$STATUS" | grep "UnitFileState=" | cut -d'=' -f2)

		log "DEBUG" "$SERVICE - Active: $ACTIVE_STATE, Sub: $SUB_STATE, Enabled: $ENABLED"

		case "$ACTIVE_STATE" in
		"active")
			if [[ $SUB_STATE == "running" ]]; then
				log "INFO" "✓ $SERVICE is running"
				return 0
			else
				log "WARN" "⚠ $SERVICE is active but not running (sub-state: $SUB_STATE)"
				return 1
			fi
			;;
		"failed")
			log "ERROR" "✗ $SERVICE has failed"
			# Show recent logs for failed services
			log "INFO" "Recent logs for $SERVICE:"
			sudo journalctl --unit="$SERVICE" --lines=10 --no-pager || true
			return 1
			;;
		"inactive")
			if [[ $SUB_STATE == "dead" ]]; then
				log "WARN" "⚠ $SERVICE is not running (inactive/dead)"
			else
				log "WARN" "⚠ $SERVICE is inactive (sub-state: $SUB_STATE)"
			fi
			return 1
			;;
		*)
			log "WARN" "⚠ $SERVICE has unknown state: $ACTIVE_STATE/$SUB_STATE"
			return 1
			;;
		esac
	else
		log "ERROR" "✗ Failed to get status for $SERVICE"
		return 1
	fi
}

function check_incus_daemon() {
	log "INFO" "Checking Incus daemon connectivity"

	if incus info >/dev/null 2>&1; then
		log "INFO" "✓ Incus daemon is responsive"

		# Get basic info
		local INCUS_VERSION
		local SERVER_NAME
		INCUS_VERSION=$(incus info | grep "server_version:" | awk '{print $2}' 2>/dev/null || echo "unknown")
		SERVER_NAME=$(incus info | grep "server_name:" | awk '{print $2}' 2>/dev/null || echo "unknown")

		log "INFO" "  - Version: $INCUS_VERSION"
		log "INFO" "  - Server: $SERVER_NAME"

		# Check if clustering is enabled
		if incus info | grep -q "server_clustered: true" 2>/dev/null; then
			log "INFO" "✓ Incus is running in cluster mode"

			# Show cluster status
			log "INFO" "Checking cluster members:"
			incus cluster list --format=table || {
				log "WARN" "Failed to list cluster members"
			}
		else
			log "INFO" "ℹ Incus is running in standalone mode"
		fi

		return 0
	else
		log "ERROR" "✗ Incus daemon is not responsive"
		return 1
	fi
}

function check_ovn_databases() {
	log "INFO" "Checking OVN database connectivity"

	local nb_status=0
	local sb_status=0

	# Check Northbound database
	log "DEBUG" "Checking OVN Northbound database"
	if sudo ovn-nbctl --timeout="$OVN_TIMEOUT" list nb_global >/dev/null 2>&1; then
		log "INFO" "✓ OVN Northbound database is responsive"

		# Get database info
		local nb_connections
		nb_connections=$(sudo ovn-nbctl --timeout="$OVN_TIMEOUT" --format=json list connection 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
		log "INFO" "  - Northbound connections: $nb_connections"
	else
		log "ERROR" "✗ OVN Northbound database is not responsive"
		nb_status=1
	fi

	# Check Southbound database
	log "DEBUG" "Checking OVN Southbound database"
	if sudo ovn-sbctl --timeout="$OVN_TIMEOUT" list sb_global >/dev/null 2>&1; then
		log "INFO" "✓ OVN Southbound database is responsive"

		# Get chassis info
		local chassis_count
		chassis_count=$(sudo ovn-sbctl --timeout="$OVN_TIMEOUT" list chassis 2>/dev/null | grep -c "^_uuid" 2>/dev/null || echo "0")
		log "INFO" "  - Chassis count: $chassis_count"

		if [[ $chassis_count -gt 0 ]]; then
			log "INFO" "Chassis list:"
			sudo ovn-sbctl --timeout="$OVN_TIMEOUT" --format=table list chassis | head -20 || true
		fi
	else
		log "ERROR" "✗ OVN Southbound database is not responsive"
		sb_status=1
	fi

	return $((nb_status + sb_status))
}

function check_ovn_controller() {
	log "INFO" "Checking OVN controller status"

	# Check if controller is connected to databases
	if sudo ovs-vsctl --timeout="$OVN_TIMEOUT" get open_vswitch . external_ids:ovn-remote >/dev/null 2>&1; then
		local ovn_remote
		ovn_remote=$(sudo ovs-vsctl get open_vswitch . external_ids:ovn-remote 2>/dev/null | tr -d '"' || echo "unknown")
		log "INFO" "✓ OVN controller is configured"
		log "INFO" "  - Remote: $ovn_remote"

		# Check system-id
		local system_id
		system_id=$(sudo ovs-vsctl get open_vswitch . external_ids:system-id 2>/dev/null | tr -d '"' || echo "unknown")
		log "INFO" "  - System ID: $system_id"

		# Check for integration bridge
		if sudo ovs-vsctl br-exists br-int 2>/dev/null; then
			log "INFO" "✓ Integration bridge (br-int) exists"
		else
			log "WARN" "⚠ Integration bridge (br-int) not found"
			return 1
		fi

		return 0
	else
		log "ERROR" "✗ OVN controller is not properly configured"
		return 1
	fi
}

function check_ovn_logical_topology() {
	log "INFO" "Checking OVN logical topology"

	local switch_count=0
	local router_count=0

	# Check logical switches
	if switch_count=$(sudo ovn-nbctl --timeout="$OVN_TIMEOUT" ls-list 2>/dev/null | wc -l) && [[ $switch_count =~ ^[0-9]+$ ]]; then
		log "INFO" "✓ Logical switches: $switch_count"
		if [[ $switch_count -gt 0 ]]; then
			log "DEBUG" "Logical switches:"
			sudo ovn-nbctl --timeout="$OVN_TIMEOUT" ls-list 2>/dev/null | head -10 || true
		fi
	else
		log "WARN" "⚠ Could not get logical switch count"
	fi

	# Check logical routers
	if router_count=$(sudo ovn-nbctl --timeout="$OVN_TIMEOUT" lr-list 2>/dev/null | wc -l) && [[ $router_count =~ ^[0-9]+$ ]]; then
		log "INFO" "✓ Logical routers: $router_count"
		if [[ $router_count -gt 0 ]]; then
			log "DEBUG" "Logical routers:"
			sudo ovn-nbctl --timeout="$OVN_TIMEOUT" lr-list 2>/dev/null | head -10 || true
		fi
	else
		log "WARN" "⚠ Could not get logical router count"
	fi

	return 0
}

function check_network_connectivity() {
	log "INFO" "Checking network connectivity"

	# Check if required sockets exist
	local socket_status=0

	if [[ -S $OVN_NB_SOCKET ]]; then
		log "INFO" "✓ OVN Northbound socket exists: $OVN_NB_SOCKET"
	else
		log "WARN" "⚠ OVN Northbound socket missing: $OVN_NB_SOCKET"
		socket_status=1
	fi

	if [[ -S $OVN_SB_SOCKET ]]; then
		log "INFO" "✓ OVN Southbound socket exists: $OVN_SB_SOCKET"
	else
		log "WARN" "⚠ OVN Southbound socket missing: $OVN_SB_SOCKET"
		socket_status=1
	fi

	# Check OVS database socket
	if [[ -S "/run/openvswitch/db.sock" ]]; then
		log "INFO" "✓ OVS database socket exists"
	else
		log "WARN" "⚠ OVS database socket missing"
		socket_status=1
	fi

	return $socket_status
}

function show_summary() {
	local TOTAL_CHECKS=$1
	local FAILED_CHECKS=$2

	log "INFO" "Health check summary:"
	log "INFO" "  - Total checks: $TOTAL_CHECKS"
	log "INFO" "  - Failed checks: $FAILED_CHECKS"
	log "INFO" "  - Success rate: $(((TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS))%"

	if [[ $FAILED_CHECKS -eq 0 ]]; then
		log "INFO" "✓ All health checks passed!"
		return 0
	else
		log "ERROR" "✗ $FAILED_CHECKS health check(s) failed"
		return 1
	fi
}

##################################################
# Main Health Check
##################################################

function main() {
	local failed_checks=0
	local total_checks=0

	log "INFO" "Starting Incus and OVN health check..."
	log "INFO" "Hostname: $(hostname)"
	log "INFO" "Date: $(date)"

	# Check systemd services
	log "INFO" "=== Checking systemd services ==="
	for service in "${SERVICES[@]}"; do
		((total_checks++))
		if ! check_systemd_service "$service"; then
			((failed_checks++))
		fi
	done

	# Check Incus daemon
	log "INFO" "=== Checking Incus daemon ==="
	((total_checks++))
	if ! check_incus_daemon; then
		((failed_checks++))
	fi

	# Check network connectivity
	log "INFO" "=== Checking network connectivity ==="
	((total_checks++))
	if ! check_network_connectivity; then
		((failed_checks++))
	fi

	# Check OVN databases
	log "INFO" "=== Checking OVN databases ==="
	((total_checks++))
	if ! check_ovn_databases; then
		((failed_checks++))
	fi

	# Check OVN controller
	log "INFO" "=== Checking OVN controller ==="
	((total_checks++))
	if ! check_ovn_controller; then
		((failed_checks++))
	fi

	# Check OVN logical topology
	log "INFO" "=== Checking OVN logical topology ==="
	((total_checks++))
	if ! check_ovn_logical_topology; then
		((failed_checks++))
	fi

	# Show summary
	log "INFO" "=== Health check complete ==="
	show_summary $total_checks $failed_checks
}

##################################################
# Script execution
##################################################

main "$@"
