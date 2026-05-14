#!/usr/bin/env bash

# Default Settings
ACTION=""
SCREEN_LOG_LEVEL="INFO"
FILE_LOG_LEVEL="DEBUG"
LOG_FILE="/tmp/gemini-extensions.log"

# Extension Definitions
declare -A GEMINI_CLI_EXTENSIONS
GEMINI_CLI_EXTENSIONS=(
	["github-mcp-server"]="https://github.com/github/github-mcp-server"
	#["nanobanana"]="https://github.com/gemini-cli-extensions/nanobanana"
	#["security"]="https://github.com/gemini-cli-extensions/security"
	#["slash-criticalthink"]="https://github.com/abagames/slash-criticalthink"
	#["stripe-ai"]="https://github.com/stripe/ai"
	#["terraform-mcp-server"]="https://github.com/hashicorp/terraform-mcp-server"
	#["vault-mcp-server"]="https://github.com/hashicorp/vault-mcp-server"
	#["workspace"]="https://github.com/gemini-cli-extensions/workspace"
)

# Logging Levels Priority
declare -A LEVELS=([DEBUG]=0 [INFO]=1 [SUCCESS]=2 [WARN]=3 [ERROR]=4)

usage() {
	echo "Usage: gemini-extensions --action [install|uninstall] [options]"
	echo ""
	echo "Options:"
	echo "  --action <act>       Action to perform: install or uninstall"
	echo "  --log-level <lvl>    Screen log level: DEBUG, INFO, SUCCESS, WARN, ERROR (Default: INFO)"
	echo "  --log-file <path>    Path to log file (Default: /tmp/gemini-extensions.log)"
	exit 1
}

# Simple Argument Parser
while [[ $# -gt 0 ]]; do
	case $1 in
	--action)
		ACTION="$2"
		shift 2
		;;
	--log-level)
		SCREEN_LOG_LEVEL="${2^^}"
		shift 2
		;;
	--log-file)
		LOG_FILE="$2"
		shift 2
		;;
	install | uninstall)
		ACTION="$1"
		shift 1
		;; # Support positional for backward compatibility
	*) usage ;;
	esac
done

[ -z "$ACTION" ] && usage

# Log Function
log() {
	local level="${1^^}"
	local message="$2"
	local timestamp
	timestamp=$(date "+%Y-%m-%d %H:%M:%S")

	local emoji color
	case $level in
	DEBUG)
		emoji="🐛"
		color="\033[0;36m"
		;; # Cyan
	INFO)
		emoji="ℹ️ "
		color="\033[0;34m"
		;; # Blue
	SUCCESS)
		emoji="✅"
		color="\033[0;32m"
		;; # Green
	WARN)
		emoji="⚠️ "
		color="\033[0;33m"
		;; # Yellow
	ERROR)
		emoji="❌"
		color="\033[0;31m"
		;; # Red
	*)
		emoji="📝"
		color="\033[0m"
		;;
	esac

	# 1. Screen Logging (with color and emoji)
	if [[ ${LEVELS[$level]} -ge ${LEVELS[$SCREEN_LOG_LEVEL]} ]]; then
		echo -e "${color}[$timestamp] $emoji [$level] $message\033[0m"
	fi

	# 2. File Logging (stripped of color and emoji)
	if [[ ${LEVELS[$level]} -ge ${LEVELS[$FILE_LOG_LEVEL]} ]]; then
		# Strip ANSI color codes and the emoji
		echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
	fi
}

# Initialization
: >"$LOG_FILE"
log INFO "Starting gemini-extensions manager (Action: $ACTION)"
log INFO "Full debug log available at: $LOG_FILE"

# Pre-flight checks
for cmd in gemini jq; do
	if ! type "$cmd" >/dev/null 2>&1; then
		log ERROR "$cmd not found. Please ensure it is installed and on PATH."
		exit 1
	fi
done

success_count=0
fail_count=0

# Get currently installed extensions
INSTALLED_JSON=$(gemini extensions list --output-format json 2>/dev/null || echo "[]")

is_installed() {
	echo "$INSTALLED_JSON" | jq -e ".[] | select(.name == \"$1\")" >/dev/null
}

case "$ACTION" in
"install")
	for name in "${!GEMINI_CLI_EXTENSIONS[@]}"; do
		url="${GEMINI_CLI_EXTENSIONS[$name]}"

		if is_installed "$name"; then
			log INFO "Updating: $name"
			if gemini extensions update "$name" >>"$LOG_FILE" 2>&1; then
				log SUCCESS "Updated $name"
				((success_count++))
			else
				log ERROR "Update failed for $name. Check $LOG_FILE"
				((fail_count++))
			fi
		else
			log INFO "Installing: $url"
			if gemini extensions install "$url" --auto-update --consent >>"$LOG_FILE" 2>&1; then
				log SUCCESS "Installed $name"
				((success_count++))
			else
				if grep -q "already installed" "$LOG_FILE"; then
					log WARN "$name reported as already installed. Forcing update..."
					if gemini extensions update "$name" >>"$LOG_FILE" 2>&1; then
						log SUCCESS "Updated $name"
						((success_count++))
					else
						log ERROR "Forced update failed for $name."
						((fail_count++))
					fi
				else
					log ERROR "Install failed for $url."
					((fail_count++))
				fi
			fi
		fi
	done
	log INFO "Summary: $success_count succeeded, $fail_count failed."
	;;

"uninstall")
	EXT_DIR="$HOME/.gemini/extensions"
	if [ ! -d "$EXT_DIR" ]; then
		log WARN "No extensions directory found."
		exit 0
	fi

	for entry in "$EXT_DIR"/*; do
		[ ! -d "$entry" ] && continue
		name=$(basename "$entry")
		log INFO "Removing: $name"
		if gemini extensions uninstall "$name" >>"$LOG_FILE" 2>&1; then
			log SUCCESS "Removed $name"
			((success_count++))
		else
			log ERROR "Removal failed for $name."
			((fail_count++))
		fi
	done
	log INFO "Summary: $success_count removed, $fail_count failed."
	;;

*)
	log ERROR "Invalid action: $ACTION"
	usage
	;;
esac
