#!/usr/bin/env bash

usage() {
	echo "Usage: gemini-extensions <command>"
	echo ""
	echo "Commands:"
	echo "  install    Install all extensions (auto-updates already-installed ones)"
	echo "  uninstall  Uninstall EVERY installed extension (based on ~/.gemini/extensions/* folder names)"
	exit 1
}

ACTION=${1:-}
[ -z "$ACTION" ] && usage

# Associative array:
#  - KEY = extension name (folder)
#  - VALUE = extension URL:
declare -A GEMINI_CLI_EXTENSIONS
GEMINI_CLI_EXTENSIONS=(
	# [agent-md]="https://github.com/Olshansk/agent-md"
	# [cloudflare-mcp]="https://github.com/ZhanZiyuan/cloudflare-mcp"
	# [code-review]="https://github.com/gemini-cli-extensions/code-review"
	# [commitzen]="https://github.com/fiquellcarter/commitzen"
	# [conductor]="https://github.com/gemini-cli-extensions/conductor"
	# [dynatrace-mcp]="https://github.com/dynatrace-oss/dynatrace-mcp"
	# [elevenlabs-mcp]="https://github.com/elevenlabs/elevenlabs-mcp"
	# [gcloud]="https://github.com/gemini-cli-extensions/gcloud"
	# [genai-toolbox]="https://github.com/googleapis/genai-toolbox"
	# [genkit]="https://github.com/gemini-cli-extensions/genkit"
	# [github-mcp-server]="https://github.com/github/github-mcp-server"
	# [gitops-extension]="https://github.com/mikebz/gitops-extension"
	# [jules]="https://github.com/gemini-cli-extensions/jules"
	# [mcp-grafana]="https://github.com/grafana/mcp-grafana"
	# [mcp-redis]="https://github.com/redis/mcp-redis"
	# [mcp-toolbox]="https://github.com/gemini-cli-extensions/mcp-toolbox"
	# [nanobanana]="https://github.com/gemini-cli-extensions/nanobanana"
	# [observability]="https://github.com/gemini-cli-extensions/observability"
	[pickle - rick - extension]="https://github.com/galz10/pickle-rick-extension"
	# [postgres]="https://github.com/gemini-cli-extensions/postgres"
	# [security]="https://github.com/gemini-cli-extensions/security"
	# [slash-criticalthink]="https://github.com/abagames/slash-criticalthink"
	# [stripe-ai]="https://github.com/stripe/ai"
	# [terraform-mcp-server]="https://github.com/hashicorp/terraform-mcp-server"
	# [vault-mcp-server]="https://github.com/hashicorp/vault-mcp-server"
	# [workspace]="https://github.com/gemini-cli-extensions/workspace"
)

log() {
	local level=$1
	local message=$2
	local color
	case $level in
	INFO | SUCCESS) color='\033[0;32m' ;;
	WARN) color='\033[0;33m' ;;
	ERROR) color='\033[0;31m' ;;
	*) color='\033[0m' ;;
	esac
	echo -e "${color}[${level}] ${message}\033[0m"
}

if ! type gemini >/dev/null 2>&1; then
	log ERROR "gemini cli not found. Please run this from a location where the gemini cli is installed."
	exit 1
fi

if ! type jq >/dev/null 2>&1; then
	log ERROR "jq not found. Please ensure jq is installed and available on PATH."
	exit 1
fi

if ! type python3 >/dev/null 2>&1; then
	log ERROR "python3 not found. Please ensure python3 is installed and available on PATH."
	exit 1
fi

success_count=0
skip_count=0
fail_count=0

case "$ACTION" in
"install")
	for ext_name in "${!GEMINI_CLI_EXTENSIONS[@]}"; do
		ext_url="${GEMINI_CLI_EXTENSIONS[$ext_name]}"
		if [ -d "$HOME/.gemini/extensions/$ext_name" ]; then
			log INFO "Updating gemini cli extension: $ext_name"
			stderr_tmp=$(mktemp)
			output=$(gemini extensions update "$ext_name" 2>"$stderr_tmp")
			cmd_exit=$?
			captured_stderr=$(cat "$stderr_tmp")
			rm "$stderr_tmp"
			if [ $cmd_exit -eq 0 ]; then
				log SUCCESS "Gemini cli extension $ext_name updated successfully"
				success_count=$((success_count + 1))
			else
				log ERROR "Failed to update gemini cli extension: $ext_name"
				log ERROR "Output: $output $captured_stderr"
				fail_count=$((fail_count + 1))
			fi
		else
			log INFO "Installing gemini cli extension: $ext_url"
			stderr_tmp=$(mktemp)
			output=$(gemini extensions install \
				"$ext_url" \
				--auto-update \
				--consent 2>"$stderr_tmp")
			cmd_exit=$?
			captured_stderr=$(cat "$stderr_tmp")
			rm "$stderr_tmp"
			if [ $cmd_exit -eq 0 ]; then
				log SUCCESS "Gemini cli extension $ext_url installed successfully"
				success_count=$((success_count + 1))
			else
				log ERROR "Failed to install gemini cli extension: $ext_url"
				log ERROR "Output: $output $captured_stderr"
				fail_count=$((fail_count + 1))
			fi
		fi
	done
	log INFO "Summary: $success_count installed/updated, $skip_count skipped, $fail_count failed."
	;;
"uninstall")
	EXT_DIR="$HOME/.gemini/extensions"
	if [ ! -d "$EXT_DIR" ]; then
		log INFO "No extensions directory found at $EXT_DIR"
		exit 0
	fi

	found_any=0
	for entry in "$EXT_DIR"/*; do
		[ ! -e "$entry" ] && continue
		[ ! -d "$entry" ] && continue
		ext_name="$(basename "$entry")"
		[ -z "$ext_name" ] && continue
		found_any=1
		log INFO "Removing gemini cli extension: $ext_name"
		stderr_tmp=$(mktemp)
		output=$(gemini extensions uninstall "$ext_name" 2>"$stderr_tmp")
		remove_exit=$?
		captured_stderr=$(cat "$stderr_tmp")
		rm "$stderr_tmp"
		if [ $remove_exit -eq 0 ]; then
			log SUCCESS "Gemini cli extension $ext_name removed successfully"
			success_count=$((success_count + 1))
		else
			log ERROR "Failed to remove gemini cli extension: $ext_name"
			log ERROR "Output: $output $captured_stderr"
			fail_count=$((fail_count + 1))
		fi
	done

	if [ $found_any -eq 0 ]; then
		log INFO "No extensions found to uninstall in $EXT_DIR."
		exit 0
	fi

	log INFO "Summary: $success_count removed, $skip_count skipped, $fail_count failed."
	;;
*)
	log ERROR "Unknown command: $ACTION"
	usage
	;;
esac
