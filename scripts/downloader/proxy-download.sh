#!/usr/bin/env bash

LOG_FILE="proxy_download.log"

# Function to handle logging to both console and file
log() {
	local message
	message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
	echo "$message" | tee -a "$LOG_FILE"
}

# 1. Parse arguments to find --url
URL=""
while [[ $# -gt 0 ]]; do
	case $1 in
	--url)
		URL="$2"
		shift # Past argument
		;;
	*)
		log "Error: Unknown parameter passed: $1"
		echo "Usage: ./proxy-download.sh --url <https_url>"
		exit 1
		;;
	esac
	shift # Past value
done

if [ -z "$URL" ]; then
	log "Error: Missing required --url argument."
	echo "Usage: ./proxy-download.sh --url <https_url>"
	exit 1
fi

log "--- Starting Proxy Download Script ---"

# 2. Get username automatically
PROXY_USER=$(whoami)
log "Using proxy username: $PROXY_USER"

# 3. Check for password in environment, prompt if missing
if [ -z "$PROXY_PASS" ]; then
	echo -n "Enter proxy password: "
	read -rs PROXY_PASS
	echo ""
	log "Password securely captured from prompt."
else
	log "Password received from environment (Wrapper Mode)."
fi

# 4. URL-encode function for special characters
urlencode() {
	local length="${#1}"
	for ((i = 0; i < length; i++)); do
		local c="${1:i:1}"
		case $c in
		[a-zA-Z0-9.~_-]) printf "%s" "$c" ;;
		*) printf '%%%02X' "'$c" ;;
		esac
	done
}

ENCODED_USER=$(urlencode "$PROXY_USER")
ENCODED_PASS=$(urlencode "$PROXY_PASS")

# 5. Extract the proxy address from ~/.wgetrc
WGETRC_PROXY=$(grep -iE '^\s*https_proxy\s*=' ~/.wgetrc | head -n 1 | cut -d'=' -f2- | tr -d ' "')

if [ -z "$WGETRC_PROXY" ]; then
	log "Error: Could not find https_proxy in ~/.wgetrc"
	exit 1
fi

CLEAN_PROXY=${WGETRC_PROXY#*://}
log "Parsed proxy from .wgetrc: $CLEAN_PROXY"

# 6. Execute wget
log "Initiating download for: $URL"
log "Wget output is being appended to $LOG_FILE"

# Added -c flag to resume broken downloads
wget -c -a "$LOG_FILE" \
	-e "https_proxy=http://${ENCODED_USER}:${ENCODED_PASS}@${CLEAN_PROXY}" \
	"$URL" || {
	log "Error: Download failed or was interrupted. Review $LOG_FILE for details."
	exit 1
}

log "Download completed successfully."

exit 0
