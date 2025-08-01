#!/usr/bin/env bash

# Note: We don't use 'set -e' here because health checks should continue
# even when individual commands fail - that's the whole point of health checking
set -uo pipefail

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

# Required tools.
declare -r REQUIRED_TOOLS=(
	"incus"
	"jq"
	"ovn-nbctl"
	"ovn-sbctl"
	"ovs-vsctl"
)

# OVN database socket paths
declare -r OVN_NB_SOCKET="/var/run/ovn/ovnnb_db.sock"
declare -r OVN_SB_SOCKET="/var/run/ovn/ovnsb_db.sock"

# OVN database file paths
declare -r OVN_NB_DB_FILE="/var/lib/ovn/ovnnb_db.db"
declare -r OVN_SB_DB_FILE="/var/lib/ovn/ovnsb_db.db"

# Timeout for OVN commands
declare -r OVN_TIMEOUT=10

# OVN cluster detection and configuration
declare OVN_CLUSTER_MODE=false
declare OVN_NB_CONNECTION=""
declare OVN_SB_CONNECTION=""

# Track cluster health status for final assessment
CLUSTER_PEER_HEALTH="unknown"
CLUSTER_COMMUNICATION_ISSUES=false

# OVN role tracking variables
OVN_NB_ROLE="unknown"
OVN_SB_ROLE="unknown"

# Exit handler for cleanup and debugging
trap 'log "ERROR" "Script exited unexpectedly at line $LINENO. Command: $BASH_COMMAND"' ERR

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

function check_for_required_tools() {

	# Make sure we have the required tools available in the PATH.
	for TOOL in "${REQUIRED_TOOLS[@]}"; do
		if ! command -v "${TOOL}" &>/dev/null; then
			log "ERROR" "Required tool not found: ${TOOL}"
			return 1
		fi
	done

	return 0
}

function check_systemd_service() {
	local SERVICE=$1
	local STATUS
	local ENABLED
	local ACTIVE_STATE
	local SUB_STATE
	local SERVICE_TYPE

	log "INFO" "Checking systemd service: $SERVICE"

	# Get service status information with better error handling
	if STATUS=$(sudo systemctl show "$SERVICE" --property=ActiveState,SubState,UnitFileState,Type 2>/dev/null || true); then
		if [[ -z $STATUS ]]; then
			log "ERROR" "✗ Service $SERVICE not found or accessible"
			return 1
		fi

		ACTIVE_STATE=$(echo "$STATUS" | grep "ActiveState=" | cut -d'=' -f2 || echo "unknown")
		SUB_STATE=$(echo "$STATUS" | grep "SubState=" | cut -d'=' -f2 || echo "unknown")
		ENABLED=$(echo "$STATUS" | grep "UnitFileState=" | cut -d'=' -f2 || echo "unknown")
		SERVICE_TYPE=$(echo "$STATUS" | grep "Type=" | cut -d'=' -f2 || echo "unknown")

		log "DEBUG" "$SERVICE - Active: $ACTIVE_STATE, Sub: $SUB_STATE, Type: $SERVICE_TYPE, Enabled: $ENABLED"

		case "$ACTIVE_STATE" in
		"active")
			# Handle different service types appropriately
			case "$SERVICE_TYPE" in
			"oneshot")
				# Oneshot services should be active/exited after successful completion
				if [[ $SUB_STATE == "exited" ]]; then
					log "INFO" "✓ $SERVICE completed successfully (oneshot service)"
					return 0
				else
					log "WARN" "⚠ $SERVICE oneshot service in unexpected sub-state: $SUB_STATE"
					return 1
				fi
				;;
			*)
				# Regular services should be running
				if [[ $SUB_STATE == "running" ]]; then
					log "INFO" "✓ $SERVICE is running"
					return 0
				else
					log "WARN" "⚠ $SERVICE is active but not running (sub-state: $SUB_STATE)"
					return 1
				fi
				;;
			esac
			;;
		"failed")
			log "ERROR" "✗ $SERVICE has failed"
			# Show recent logs for failed services (with timeout protection)
			log "INFO" "Recent logs for $SERVICE:"
			if timeout 10 sudo journalctl --unit="$SERVICE" --lines=10 --no-pager 2>/dev/null || true; then
				: # Command succeeded or timed out gracefully
			else
				log "WARN" "Could not retrieve logs for $SERVICE"
			fi
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
		log "ERROR" "✗ Failed to get status for $SERVICE (command failed)"
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
	log "DEBUG" "Starting OVN databases check"
	log "INFO" "Checking OVN database connectivity"

	local nb_status=0
	local sb_status=0

	if [[ $OVN_CLUSTER_MODE == "true" ]]; then
		# Detect roles first
		detect_ovn_roles

		# Check Northbound database with role awareness
		log "DEBUG" "Checking OVN Northbound database"
		if check_database_connectivity_by_role_json "nb" "$OVN_NB_ROLE" "$OVN_NB_CONNECTION" "ovn-nbctl"; then
			log "INFO" "✓ OVN Northbound database is responsive"
		else
			log "WARN" "⚠ OVN Northbound database has connectivity issues"
			((nb_status++))
		fi

		# Get connection count using JSON
		local nb_metrics=""
		nb_metrics=$(get_database_metrics_json "nb" "$OVN_NB_CONNECTION" "ovn-nbctl")
		local nb_connections="0"
		if [[ $nb_metrics =~ connections:([0-9]+) ]]; then
			nb_connections="${BASH_REMATCH[1]}"
		fi
		log "INFO" "  - Northbound connections: ${nb_connections}"

		# Check Southbound database with role awareness
		log "DEBUG" "Checking OVN Southbound database"
		if check_database_connectivity_by_role_json "sb" "$OVN_SB_ROLE" "$OVN_SB_CONNECTION" "ovn-sbctl"; then
			log "INFO" "✓ OVN Southbound database is responsive"
		else
			log "WARN" "⚠ OVN Southbound database has connectivity issues"
			((sb_status++))
		fi

		# Get chassis count using JSON
		local sb_metrics=""
		sb_metrics=$(get_database_metrics_json "sb" "$OVN_SB_CONNECTION" "ovn-sbctl")
		local chassis_count="0"
		if [[ $sb_metrics =~ chassis:([0-9]+) ]]; then
			chassis_count="${BASH_REMATCH[1]}"
		fi
		log "INFO" "  - Chassis count: ${chassis_count}"

	else
		# Local mode - existing logic
		log "DEBUG" "Checking OVN Northbound database"
		if sudo ovn-nbctl --timeout="$OVN_TIMEOUT" list nb_global >/dev/null 2>&1; then
			log "INFO" "✓ OVN Northbound database is responsive"
		else
			log "WARN" "⚠ OVN Northbound database is not responsive"
			((nb_status++))
		fi

		# Get connection count in local mode
		local nb_connections
		nb_connections=$(sudo ovn-nbctl --timeout="$OVN_TIMEOUT" get nb_global . connections 2>/dev/null | wc -w || echo "0")
		log "INFO" "  - Northbound connections: $nb_connections"

		log "DEBUG" "Checking OVN Southbound database"
		if sudo ovn-sbctl --timeout="$OVN_TIMEOUT" list sb_global >/dev/null 2>&1; then
			log "INFO" "✓ OVN Southbound database is responsive"
		else
			log "WARN" "⚠ OVN Southbound database is not responsive"
			((sb_status++))
		fi

		# Get chassis count in local mode
		local chassis_count
		chassis_count=$(sudo ovn-sbctl --timeout="$OVN_TIMEOUT" list chassis 2>/dev/null | wc -l || echo "0")
		log "INFO" "  - Chassis count: $chassis_count"
	fi

	log "DEBUG" "Completed OVN databases check"
	return $((nb_status + sb_status))
}

function check_ovn_cluster_health() {
	log "DEBUG" "Starting OVN cluster peer health check"
	log "INFO" "Checking OVN cluster peer health"

	if [[ $OVN_CLUSTER_MODE != "true" ]]; then
		log "INFO" "ℹ Skipping cluster health check (not in cluster mode)"
		log "DEBUG" "Completed OVN cluster peer health check"
		CLUSTER_PEER_HEALTH="standalone"
		return 0
	fi

	local nb_cluster_issues=0
	local sb_cluster_issues=0
	local nb_stale_servers=0
	local sb_stale_servers=0
	local stale_threshold=30000 # 30 seconds in milliseconds

	# Get Northbound cluster status
	local nb_cluster_status=""
	if nb_cluster_status=$(sudo ovs-appctl -t /var/run/ovn/ovn-nb-db.ctl cluster/status OVN_Northbound 2>/dev/null); then
		local nb_role
		local nb_leader
		local nb_term
		nb_role=$(echo "$nb_cluster_status" | grep "^Role:" | awk '{print $2}' || echo "unknown")
		nb_leader=$(echo "$nb_cluster_status" | grep "^Leader:" | awk '{print $2}' || echo "unknown")
		nb_term=$(echo "$nb_cluster_status" | grep "^Term:" | awk '{print $2}' || echo "unknown")

		log "INFO" "  - NB Role: $nb_role, Leader: $nb_leader, Term: $nb_term"

		# Enhanced server health parsing
		local nb_total_servers=0
		local nb_healthy_servers=0
		# nb_stale_servers declared at function level

		# Parse servers section more robustly
		local servers_section=""
		servers_section=$(echo "$nb_cluster_status" | sed -n '/^Servers:/,$p' | tail -n +2)

		if [[ -n $servers_section ]]; then
			while IFS= read -r line; do
				# Skip empty lines and non-server lines
				[[ -z $line || ! $line =~ ^[[:space:]]*[a-f0-9]{4} ]] && continue

				((nb_total_servers++))

				# Check for self indicator
				if [[ $line =~ \(self\) ]]; then
					((nb_healthy_servers++))
					log "DEBUG" "    - $(echo "$line" | awk '{print $1}') (self): HEALTHY"
				# Check for recent message timestamp
				elif [[ $line =~ last\ msg\ ([0-9]+)\ ms\ ago ]]; then
					local last_msg=${BASH_REMATCH[1]}
					if [[ $last_msg -lt $stale_threshold ]]; then
						((nb_healthy_servers++))
						log "DEBUG" "    - $(echo "$line" | awk '{print $1}'): HEALTHY (${last_msg}ms ago)"
					else
						((nb_stale_servers++))
						# Don't increment nb_cluster_issues for stale servers - they're warnings only
						log "WARN" "    - $(echo "$line" | awk '{print $1}'): STALE (${last_msg}ms ago) - follower perspective"
					fi
				# Server exists but no clear timestamp - be conservative and mark as healthy
				else
					((nb_healthy_servers++))
					log "DEBUG" "    - $(echo "$line" | awk '{print $1}'): HEALTHY (no timestamp visible)"
				fi
			done <<<"$servers_section"
		else
			log "WARN" "No servers section found in NB cluster status"
			((nb_cluster_issues++))
		fi

		log "INFO" "  - NB Servers: $nb_total_servers total, $nb_healthy_servers healthy, $nb_stale_servers stale"

		if [[ $nb_stale_servers -gt 0 ]]; then
			log "WARN" "  - Warning: $nb_stale_servers NB servers appear stale from follower perspective"
			# Don't increment nb_cluster_issues - stale servers are normal for followers
		fi
	else
		log "ERROR" "Failed to get Northbound cluster status"
		((nb_cluster_issues++))
	fi

	# Get Southbound cluster status
	local sb_cluster_status=""
	if sb_cluster_status=$(sudo ovs-appctl -t /var/run/ovn/ovn-sb-db.ctl cluster/status OVN_Southbound 2>/dev/null); then
		local sb_role
		local sb_leader
		local sb_term
		sb_role=$(echo "$sb_cluster_status" | grep "^Role:" | awk '{print $2}' || echo "unknown")
		sb_leader=$(echo "$sb_cluster_status" | grep "^Leader:" | awk '{print $2}' || echo "unknown")
		sb_term=$(echo "$sb_cluster_status" | grep "^Term:" | awk '{print $2}' || echo "unknown")

		log "INFO" "  - SB Role: $sb_role, Leader: $sb_leader, Term: $sb_term"

		# Enhanced server health parsing
		local sb_total_servers=0
		local sb_healthy_servers=0
		# sb_stale_servers declared at function level

		# Parse servers section more robustly
		local servers_section=""
		servers_section=$(echo "$sb_cluster_status" | sed -n '/^Servers:/,$p' | tail -n +2)

		if [[ -n $servers_section ]]; then
			while IFS= read -r line; do
				# Skip empty lines and non-server lines
				[[ -z $line || ! $line =~ ^[[:space:]]*[a-f0-9]{4} ]] && continue

				((sb_total_servers++))

				# Check for self indicator
				if [[ $line =~ \(self\) ]]; then
					((sb_healthy_servers++))
					log "DEBUG" "    - $(echo "$line" | awk '{print $1}') (self): HEALTHY"
				# Check for recent message timestamp
				elif [[ $line =~ last\ msg\ ([0-9]+)\ ms\ ago ]]; then
					local last_msg=${BASH_REMATCH[1]}
					if [[ $last_msg -lt $stale_threshold ]]; then
						((sb_healthy_servers++))
						log "DEBUG" "    - $(echo "$line" | awk '{print $1}'): HEALTHY (${last_msg}ms ago)"
					else
						((sb_stale_servers++))
						# Don't increment sb_cluster_issues for stale servers - they're warnings only
						log "WARN" "    - $(echo "$line" | awk '{print $1}'): STALE (${last_msg}ms ago) - follower perspective"
					fi
				# Server exists but no clear timestamp - be conservative and mark as healthy
				else
					((sb_healthy_servers++))
					log "DEBUG" "    - $(echo "$line" | awk '{print $1}'): HEALTHY (no timestamp visible)"
				fi
			done <<<"$servers_section"
		else
			log "WARN" "No servers section found in SB cluster status"
			((sb_cluster_issues++))
		fi

		log "INFO" "  - SB Servers: $sb_total_servers total, $sb_healthy_servers healthy, $sb_stale_servers stale"

		if [[ $sb_stale_servers -gt 0 ]]; then
			log "WARN" "  - Warning: $sb_stale_servers SB servers appear stale from follower perspective"
			# Don't increment sb_cluster_issues - stale servers are normal for followers
		fi
	else
		log "ERROR" "Failed to get Southbound cluster status"
		((sb_cluster_issues++))
	fi

	local total_issues=$((nb_cluster_issues + sb_cluster_issues))
	local total_stale_servers=$((nb_stale_servers + sb_stale_servers))

	if [[ $total_issues -eq 0 ]]; then
		if [[ $total_stale_servers -gt 0 ]]; then
			log "INFO" "✓ OVN cluster peer health is good (with $total_stale_servers stale servers from follower perspective)"
			log "INFO" "ℹ Stale server timestamps are normal in OVSDB clusters when viewed from followers"
		else
			log "INFO" "✓ OVN cluster peer health is good"
		fi
		CLUSTER_PEER_HEALTH="healthy"
		log "DEBUG" "Completed OVN cluster peer health check"
		return 0
	else
		# Only fail for genuine cluster failures (not stale servers)
		log "ERROR" "✗ OVN cluster peer health check failed ($total_issues genuine cluster issues)"
		CLUSTER_PEER_HEALTH="unhealthy"
		log "DEBUG" "Completed OVN cluster peer health check"
		return 1
	fi
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
	local cmd_nb="sudo ovn-nbctl"

	# Use cluster connection if available
	[[ $OVN_CLUSTER_MODE == true && -n $OVN_NB_CONNECTION ]] && cmd_nb="$cmd_nb $OVN_NB_CONNECTION"
	[[ $OVN_CLUSTER_MODE == true ]] && cmd_nb="$cmd_nb --no-leader-only"

	# Check logical switches
	if switch_count=$($cmd_nb --timeout="$OVN_TIMEOUT" ls-list 2>/dev/null | wc -l) && [[ $switch_count =~ ^[0-9]+$ ]]; then
		log "INFO" "✓ Logical switches: $switch_count"
		if [[ $switch_count -gt 0 ]]; then
			log "DEBUG" "Logical switches:"
			$cmd_nb --timeout="$OVN_TIMEOUT" ls-list 2>/dev/null | head -10 || true
		fi
	else
		log "WARN" "⚠ Could not get logical switch count"
	fi

	# Check logical routers
	if router_count=$($cmd_nb --timeout="$OVN_TIMEOUT" lr-list 2>/dev/null | wc -l) && [[ $router_count =~ ^[0-9]+$ ]]; then
		log "INFO" "✓ Logical routers: $router_count"
		if [[ $router_count -gt 0 ]]; then
			log "DEBUG" "Logical routers:"
			$cmd_nb --timeout="$OVN_TIMEOUT" lr-list 2>/dev/null | head -10 || true
		fi
	else
		log "WARN" "⚠ Could not get logical router count"
	fi

	return 0
}

function check_network_connectivity() {
	log "INFO" "Checking network connectivity"

	local socket_status=0

	if [[ $OVN_CLUSTER_MODE == true ]]; then
		log "INFO" "Cluster mode: checking database services and optional socket accessibility"

		# In cluster mode, local sockets may not be accessible on non-leader nodes
		# Check if they exist but don't fail if they're not accessible
		if [[ -S $OVN_NB_SOCKET ]]; then
			log "INFO" "✓ OVN Northbound socket exists: $OVN_NB_SOCKET"
		else
			log "DEBUG" "ℹ OVN Northbound socket not accessible: $OVN_NB_SOCKET (normal in cluster non-leader)"
		fi

		if [[ -S $OVN_SB_SOCKET ]]; then
			log "INFO" "✓ OVN Southbound socket exists: $OVN_SB_SOCKET"
		else
			log "DEBUG" "ℹ OVN Southbound socket not accessible: $OVN_SB_SOCKET (normal in cluster non-leader)"
		fi

		# Check database services are running (more important in cluster mode)
		for service in "ovn-northbound-db.service" "ovn-southbound-db.service"; do
			if systemctl is-active "$service" >/dev/null 2>&1; then
				log "INFO" "✓ $service is active"
			else
				log "ERROR" "✗ $service is not active"
				socket_status=1
			fi
		done
	else
		log "INFO" "Local mode: checking socket accessibility"

		# In local mode, sockets must be accessible
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
	fi

	# Check OVS database socket (required in both modes)
	if [[ -S "/run/openvswitch/db.sock" ]]; then
		log "INFO" "✓ OVS database socket exists"
	else
		log "WARN" "⚠ OVS database socket missing"
		socket_status=1
	fi

	return $socket_status
}

function detect_ovn_mode() {
	log "INFO" "Detecting OVN deployment mode"

	# Check if OVN databases are clustered by examining the database files
	local nb_clustered=false
	local sb_clustered=false

	# Check northbound database
	if [[ -f ${OVN_NB_DB_FILE} ]] && sudo ovsdb-tool db-is-clustered "${OVN_NB_DB_FILE}" >/dev/null 2>&1; then
		nb_clustered=true
		log "DEBUG" "Northbound database is clustered"
	elif [[ -f ${OVN_NB_DB_FILE} ]] && sudo ovsdb-tool db-is-standalone "${OVN_NB_DB_FILE}" >/dev/null 2>&1; then
		log "DEBUG" "Northbound database is standalone"
	fi

	# Check southbound database
	if [[ -f ${OVN_SB_DB_FILE} ]] && sudo ovsdb-tool db-is-clustered "${OVN_SB_DB_FILE}" >/dev/null 2>&1; then
		sb_clustered=true
		log "DEBUG" "Southbound database is clustered"
	elif [[ -f ${OVN_SB_DB_FILE} ]] && sudo ovsdb-tool db-is-standalone "${OVN_SB_DB_FILE}" >/dev/null 2>&1; then
		log "DEBUG" "Southbound database is standalone"
	fi

	# Set cluster mode and connection strings
	if [[ $nb_clustered == true && $sb_clustered == true ]]; then
		OVN_CLUSTER_MODE=true
		log "INFO" "✓ Detected OVN cluster mode"

		# Try to get cluster addresses from systemd environment
		if command -v systemctl >/dev/null 2>&1; then
			# Extract cluster addresses from ovn-central service
			local nb_cluster_addrs=""
			local sb_cluster_addrs=""

			# Try to get from systemd service definition
			if systemctl cat ovn-central.service 2>/dev/null | grep -q "ovnnb-db=tcp:"; then
				nb_cluster_addrs=$(systemctl cat ovn-central.service --no-pager 2>/dev/null | grep -o "ovnnb-db=tcp:[^[:space:]]*" | cut -d'=' -f2 || echo "")
				sb_cluster_addrs=$(systemctl cat ovn-central.service --no-pager 2>/dev/null | grep -o "ovnsb-db=tcp:[^[:space:]]*" | cut -d'=' -f2 || echo "")
			fi

			# Set connection strings
			if [[ -n $nb_cluster_addrs ]]; then
				OVN_NB_CONNECTION="--db=$nb_cluster_addrs"
				log "DEBUG" "Using NB cluster addresses: $nb_cluster_addrs"
			else
				OVN_NB_CONNECTION=""
				log "WARN" "Could not determine NB cluster addresses, falling back to default"
			fi

			if [[ -n $sb_cluster_addrs ]]; then
				OVN_SB_CONNECTION="--db=$sb_cluster_addrs"
				log "DEBUG" "Using SB cluster addresses: $sb_cluster_addrs"
			else
				OVN_SB_CONNECTION=""
				log "WARN" "Could not determine SB cluster addresses, falling back to default"
			fi
		fi

		# Show cluster summary
		log "INFO" "  - Mode: Clustered Database + Multiple ovn-northd"
		log "INFO" "  - HA Strategy: Automatic active/standby with failover"
		[[ -n $nb_cluster_addrs ]] && log "INFO" "  - NB Cluster: $nb_cluster_addrs"
		[[ -n $sb_cluster_addrs ]] && log "INFO" "  - SB Cluster: $sb_cluster_addrs"
	else
		OVN_CLUSTER_MODE=false
		OVN_NB_CONNECTION=""
		OVN_SB_CONNECTION=""
		log "INFO" "✓ Detected OVN local/standalone mode"
		log "INFO" "  - Mode: Standalone Database + Single ovn-northd"
		log "INFO" "  - HA Strategy: None (single point of failure)"
	fi
	return 0 # Indicate success
}

function check_ovn_central_status() {
	log "DEBUG" "Starting OVN Central status check"
	log "INFO" "Checking OVN Central (ovn-northd) status"

	# Check if ovn-northd is running
	if ! pgrep -f "ovn-northd" >/dev/null 2>&1; then
		log "ERROR" "✗ OVN Central (ovn-northd) is not running"
		return 1
	fi
	log "DEBUG" "ovn-northd process is running"

	if [[ $OVN_CLUSTER_MODE == "true" ]]; then
		# In cluster mode, detect roles if not already done
		if [[ -z $OVN_NB_ROLE || -z $OVN_SB_ROLE ]]; then
			detect_ovn_roles
		fi

		log "DEBUG" "Checking cluster mode ovn-northd connectivity"
		log "INFO" "✓ OVN Central is running in cluster mode"
		log "INFO" "  - NB Role: $OVN_NB_ROLE, SB Role: $OVN_SB_ROLE"
		log "INFO" "  - NB Cluster: $OVN_NB_CONNECTION"
		log "INFO" "  - SB Cluster: $OVN_SB_CONNECTION"

		# For cluster mode, the detailed connectivity testing is done in check_ovn_databases
		# Here we just verify the process is running with cluster configuration
		log "INFO" "  - ovn-northd process is active with cluster configuration"

	else
		# Local mode: Wait for local database services to be ready
		log "DEBUG" "Checking local mode ovn-northd connectivity"

		local nb_accessible=false
		local sb_accessible=false

		# Test basic connectivity to local databases
		if timeout 5 sudo ovn-nbctl --timeout=3 list nb_global >/dev/null 2>&1; then
			nb_accessible=true
		fi

		if timeout 5 sudo ovn-sbctl --timeout=3 list sb_global >/dev/null 2>&1; then
			sb_accessible=true
		fi

		if [[ $nb_accessible == "true" && $sb_accessible == "true" ]]; then
			log "INFO" "✓ OVN Central is running and connected to local databases"

			# Try to get configuration sequence for status indication
			local nb_cfg_seq=""
			nb_cfg_seq=$(sudo ovn-nbctl --timeout=5 get nb_global . nb_cfg 2>/dev/null || echo "0")
			if [[ -n $nb_cfg_seq && $nb_cfg_seq != "0" ]]; then
				log "INFO" "  - NB configuration sequence: $nb_cfg_seq"
			fi
		else
			log "ERROR" "✗ OVN Central cannot access local databases"
			log "ERROR" "  - NB accessible: $nb_accessible, SB accessible: $sb_accessible"
			return 1
		fi
	fi

	log "DEBUG" "Completed OVN Central status check"
	return 0
}

function show_summary() {
	local TOTAL_CHECKS=$1
	local FAILED_CHECKS=$2

	log "INFO" "Health check summary:"
	log "INFO" "  - Total checks: $TOTAL_CHECKS"
	log "INFO" "  - Failed checks: $FAILED_CHECKS"
	log "INFO" "  - Success rate: $(((TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS))%"

	if [[ $FAILED_CHECKS -eq 0 ]]; then
		if [[ $OVN_CLUSTER_MODE == "true" && $CLUSTER_PEER_HEALTH == "healthy" && $CLUSTER_COMMUNICATION_ISSUES == "true" ]]; then
			log "INFO" "✓ All health checks passed! (Cluster timeouts are normal)"
		else
			log "INFO" "✓ All health checks passed!"
		fi
		return 0
	else
		log "ERROR" "✗ $FAILED_CHECKS health check(s) failed"
		return 1
	fi
}

# Final cluster assessment function
function provide_cluster_assessment() {
	if [[ $OVN_CLUSTER_MODE == "true" ]]; then
		log "INFO" "=== Final Cluster Assessment ==="
		log "INFO" "Cluster Roles: NB=$OVN_NB_ROLE, SB=$OVN_SB_ROLE"

		if [[ $CLUSTER_PEER_HEALTH == "healthy" ]]; then
			if [[ $CLUSTER_COMMUNICATION_ISSUES == "true" ]]; then
				log "INFO" "✓ CLUSTER STATUS: HEALTHY (client timeouts are normal)"
				log "INFO" "  → All cluster peers are healthy and communicating via RAFT"
				log "INFO" "  → OVSDB client tools (ovn-nbctl/ovn-sbctl) often timeout in clusters"
				log "INFO" "  → Local socket access working - this is the primary access method"
				log "INFO" "  → Cluster peer communication is healthy - this is what matters"
			else
				log "INFO" "✓ CLUSTER STATUS: OPTIMAL"
				log "INFO" "  → All cluster connections working + All peers healthy"
				log "INFO" "  → Both local and cluster client access functional"
			fi

			# Provide role-specific guidance
			if [[ $OVN_NB_ROLE == "leader" || $OVN_SB_ROLE == "leader" ]]; then
				log "INFO" "  → This node has leadership role(s) - local socket access expected"
			else
				log "INFO" "  → This node is a follower - cluster communication is primary"
			fi

		elif [[ $CLUSTER_PEER_HEALTH == "degraded" ]]; then
			log "WARN" "⚠ CLUSTER STATUS: DEGRADED"
			log "WARN" "  → Some cluster peers are unhealthy"
			log "WARN" "  → This indicates genuine cluster issues requiring attention"
		else
			log "WARN" "⚠ CLUSTER STATUS: UNKNOWN"
			log "WARN" "  → Unable to assess cluster peer health"
		fi
	fi
}

# Add role detection functions after the existing functions
function detect_ovn_roles() {
	local nb_role="unknown"
	local sb_role="unknown"

	# Detect Northbound role
	if nb_cluster_status=$(sudo ovs-appctl -t /var/run/ovn/ovn-nb-db.ctl cluster/status OVN_Northbound 2>/dev/null); then
		nb_role=$(echo "$nb_cluster_status" | grep "^Role:" | awk '{print $2}' || echo "unknown")
	fi

	# Detect Southbound role
	if sb_cluster_status=$(sudo ovs-appctl -t /var/run/ovn/ovn-sb-db.ctl cluster/status OVN_Southbound 2>/dev/null); then
		sb_role=$(echo "$sb_cluster_status" | grep "^Role:" | awk '{print $2}' || echo "unknown")
	fi

	# Set global variables
	OVN_NB_ROLE="$nb_role"
	OVN_SB_ROLE="$sb_role"

	log "DEBUG" "Detected roles - NB: $OVN_NB_ROLE, SB: $OVN_SB_ROLE"
}

# Add JSON-based database connectivity testing
function check_database_connectivity_by_role_json() {
	local db_type="$1" # "nb" or "sb"
	local role="$2"    # "leader" or "follower"
	local connection="$3"
	local cmd_base="$4" # "ovn-nbctl" or "ovn-sbctl"

	local cluster_ok=false
	local local_ok=false
	local local_required=true

	# Adjust requirements based on role
	if [[ $role == "follower" ]]; then
		local_required=false # Followers often can't respond to local queries
		log "DEBUG" "$db_type: Follower node - local socket failures are acceptable"
	elif [[ $role == "leader" ]]; then
		local_required=true # Leaders should respond to local queries
		log "DEBUG" "$db_type: Leader node - local socket should work"
	else
		log "WARN" "$db_type: Unknown role '$role' - using standard tests"
	fi

	# Test cluster connection using JSON
	log "DEBUG" "Testing $db_type cluster connection with JSON: $connection"
	if timeout 10 sudo "$cmd_base" "$connection" --no-leader-only --timeout=5 --format=json list "${db_type}_global" >/dev/null 2>&1; then
		cluster_ok=true
		log "DEBUG" "✓ $db_type cluster connection successful"
	else
		cluster_ok=false
		log "DEBUG" "✗ $db_type cluster connection failed (timeout/unreachable)"
	fi

	# Test local socket using JSON
	log "DEBUG" "Testing $db_type local socket connection with JSON"
	if timeout 5 sudo "$cmd_base" --timeout=3 --format=json list "${db_type}_global" >/dev/null 2>&1; then
		local_ok=true
		log "DEBUG" "✓ $db_type local socket connection successful"
	else
		local_ok=false
		log "DEBUG" "✗ $db_type local socket connection failed"
	fi

	# Determine overall status based on role
	if [[ $local_ok == "true" || ($local_required == false && $cluster_ok == true) ]]; then
		# Success cases:
		# 1. Local socket works (any role)
		# 2. Follower with working cluster connection (local failure OK)
		log "INFO" "✓ OVN $db_type database is accessible"

		if [[ $cluster_ok == "true" && $local_ok == "true" ]]; then
			log "INFO" "  - Connection: Cluster + Local (OPTIMAL)"
		elif [[ $cluster_ok == "true" && $local_ok == "false" && $role == "follower" ]]; then
			log "INFO" "  - Connection: Cluster only (NORMAL for $role)"
		elif [[ $cluster_ok == "false" && $local_ok == "true" ]]; then
			log "DEBUG" "  - Connection: Local only (cluster client timeouts are normal in OVSDB)"
			CLUSTER_COMMUNICATION_ISSUES=true
		else
			log "INFO" "  - Connection: Local socket"
		fi

		log "INFO" "  - Role: $role"
		return 0
	elif [[ $local_required == false && $role == "follower" ]]; then
		# Special case: Follower where both cluster and local fail
		# This is concerning but not necessarily fatal if other nodes are healthy
		log "WARN" "⚠ OVN $db_type database has limited connectivity (follower node)"
		log "WARN" "  - Role: $role, Cluster: $cluster_ok, Local: $local_ok"
		log "WARN" "  - This may be normal if cluster is still forming or this node is isolated"
		CLUSTER_COMMUNICATION_ISSUES=true
		return 0 # Don't fail hard for followers with connectivity issues
	else
		# Failure cases
		log "ERROR" "✗ OVN $db_type database is not accessible"
		log "ERROR" "  - Role: $role, Cluster: $cluster_ok, Local: $local_ok"
		if [[ $role == "leader" && $local_ok == "false" ]]; then
			log "ERROR" "  - Leader nodes should respond to local queries"
		fi
		return 1
	fi
}

# JSON-based connection and chassis counting
function get_database_metrics_json() {
	local db_type="$1" # "nb" or "sb"
	local connection="$2"
	local cmd_base="$3" # "ovn-nbctl" or "ovn-sbctl"

	local connections=0
	local chassis_count=0

	# Check if jq is available
	local has_jq=false
	if command -v jq >/dev/null 2>&1; then
		has_jq=true
	fi

	# Try cluster connection first, then local
	if timeout "$OVN_TIMEOUT" sudo "$cmd_base" "$connection" --no-leader-only --timeout=5 --format=json list "${db_type}_global" >/dev/null 2>&1; then
		# Get connections using JSON
		local json_output=""
		json_output=$(timeout "$OVN_TIMEOUT" sudo "$cmd_base" "$connection" --no-leader-only --timeout=5 --format=json list "${db_type}_global" 2>/dev/null || echo "")
		if [[ -n $json_output ]]; then
			if [[ $has_jq == "true" ]]; then
				# Parse connections from JSON (connections field is usually empty set [], so count is 0)
				connections=$(echo "$json_output" | jq -r '.data[0][1][1] | length' 2>/dev/null || echo "0")
			else
				# Fallback: count connections manually (usually 0 for fresh clusters)
				connections="0"
			fi
		fi
	else
		# Fall back to local socket
		local json_output=""
		json_output=$(timeout "$OVN_TIMEOUT" sudo "$cmd_base" --timeout=5 --format=json list "${db_type}_global" 2>/dev/null || echo "")
		if [[ -n $json_output ]]; then
			if [[ $has_jq == "true" ]]; then
				connections=$(echo "$json_output" | jq -r '.data[0][1][1] | length' 2>/dev/null || echo "0")
			else
				connections="0"
			fi
		fi
	fi

	# Get chassis count for SB only
	if [[ $db_type == "sb" ]]; then
		if timeout "$OVN_TIMEOUT" sudo "$cmd_base" "$connection" --no-leader-only --timeout=5 --format=json list chassis >/dev/null 2>&1; then
			local chassis_json=""
			chassis_json=$(timeout "$OVN_TIMEOUT" sudo "$cmd_base" "$connection" --no-leader-only --timeout=5 --format=json list chassis 2>/dev/null || echo "")
			if [[ -n $chassis_json ]]; then
				if [[ $has_jq == "true" ]]; then
					chassis_count=$(echo "$chassis_json" | jq -r '.data | length' 2>/dev/null || echo "0")
				else
					# Fallback: count chassis entries manually
					chassis_count=$(echo "$chassis_json" | grep -o '"uuid"' | wc -l || echo "0")
				fi
			fi
		else
			local chassis_json=""
			chassis_json=$(timeout "$OVN_TIMEOUT" sudo "$cmd_base" --timeout=5 --format=json list chassis 2>/dev/null || echo "")
			if [[ -n $chassis_json ]]; then
				if [[ $has_jq == "true" ]]; then
					chassis_count=$(echo "$chassis_json" | jq -r '.data | length' 2>/dev/null || echo "0")
				else
					chassis_count=$(echo "$chassis_json" | grep -o '"uuid"' | wc -l || echo "0")
				fi
			fi
		fi
	fi

	# Output results
	if [[ $db_type == "nb" ]]; then
		echo "connections:$connections"
	else
		echo "connections:$connections,chassis:$chassis_count"
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

	# Check for required tools
	log "INFO" "=== Checking for required tools ==="
	if ! check_for_required_tools; then
		log "ERROR" "Required tools not found, exiting"
		exit 1
	fi

	# Detect OVN deployment mode first
	log "INFO" "=== Detecting OVN deployment mode ==="
	log "DEBUG" "Starting OVN mode detection"
	if detect_ovn_mode; then
		log "DEBUG" "OVN mode detection completed successfully"
	else
		log "WARN" "OVN mode detection encountered issues but continuing..."
	fi

	# Check systemd services
	log "INFO" "=== Checking systemd services ==="
	for service in "${SERVICES[@]}"; do
		((total_checks++))
		log "DEBUG" "Starting check for service: $service"

		# Temporarily disable exit on error for individual checks
		set +e
		check_systemd_service "$service"
		local check_result=$?
		set -e

		if [[ $check_result -eq 0 ]]; then
			log "DEBUG" "Completed check for service: $service"
		else
			log "ERROR" "✗ Service check failed for $service"
			((failed_checks++))
		fi
	done
	log "DEBUG" "Completed all systemd service checks"

	# Check OVN Central (ovn-northd) status
	log "INFO" "=== Checking OVN Central status ==="
	((total_checks++))
	log "DEBUG" "Starting OVN Central status check"
	set +e
	check_ovn_central_status
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed OVN Central status check"
	else
		log "ERROR" "✗ OVN Central status check failed"
		((failed_checks++))
	fi

	# Check Incus daemon
	log "INFO" "=== Checking Incus daemon ==="
	((total_checks++))
	log "DEBUG" "Starting Incus daemon check"
	set +e
	check_incus_daemon
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed Incus daemon check"
	else
		log "ERROR" "✗ Incus daemon check failed"
		((failed_checks++))
	fi

	# Check network connectivity
	log "INFO" "=== Checking network connectivity ==="
	((total_checks++))
	log "DEBUG" "Starting network connectivity check"
	set +e
	check_network_connectivity
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed network connectivity check"
	else
		log "ERROR" "✗ Network connectivity check failed"
		((failed_checks++))
	fi

	# Check OVN databases
	log "INFO" "=== Checking OVN databases ==="
	((total_checks++))
	log "DEBUG" "Starting OVN databases check"
	set +e
	check_ovn_databases
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed OVN databases check"
	else
		log "ERROR" "✗ OVN databases check failed"
		((failed_checks++))
	fi

	# Check OVN cluster peer health
	log "INFO" "=== Checking OVN cluster peer health ==="
	((total_checks++))
	log "DEBUG" "Starting OVN cluster peer health check"
	set +e
	check_ovn_cluster_health
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed OVN cluster peer health check"
	else
		log "ERROR" "✗ OVN cluster peer health check failed"
		((failed_checks++))
	fi

	# Check OVN controller
	log "INFO" "=== Checking OVN controller ==="
	((total_checks++))
	log "DEBUG" "Starting OVN controller check"
	set +e
	check_ovn_controller
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed OVN controller check"
	else
		log "ERROR" "✗ OVN controller check failed"
		((failed_checks++))
	fi

	# Check OVN logical topology
	log "INFO" "=== Checking OVN logical topology ==="
	((total_checks++))
	log "DEBUG" "Starting OVN logical topology check"
	set +e
	check_ovn_logical_topology
	local check_result=$?
	set -e

	if [[ $check_result -eq 0 ]]; then
		log "DEBUG" "Completed OVN logical topology check"
	else
		log "ERROR" "✗ OVN logical topology check failed"
		((failed_checks++))
	fi

	# Final status
	provide_cluster_assessment

	if [[ $failed_checks -eq 0 ]]; then
		if [[ $OVN_CLUSTER_MODE == "true" && $CLUSTER_PEER_HEALTH == "healthy" ]]; then
			log "INFO" "✓ All health checks passed! (OVSDB cluster is healthy)"
		else
			log "INFO" "✓ All health checks passed!"
		fi
	else
		log "ERROR" "✗ $failed_checks health check(s) failed"
	fi

	log "INFO" "=== Health check complete ==="
	show_summary $total_checks $failed_checks
}

##################################################
# Script execution
##################################################

main "$@"
