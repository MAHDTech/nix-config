#!/usr/bin/env bash

# ==========================================
# Pre-flight Checks & Setup
# ==========================================

CONFIG_FILE="downloads.txt"

if [[ ! -f $CONFIG_FILE ]]; then
	echo "❌ Error: Configuration file '$CONFIG_FILE' not found."
	exit 1
fi

REQ_DEPS=(wget sha256sum awk sed rm sleep)

echo "Checking system dependencies..."
missing_deps=0
for cmd in "${REQ_DEPS[@]}"; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "❌ Error: Required command '$cmd' is not installed or not in PATH."
		missing_deps=1
	fi
done

if [[ $missing_deps -eq 1 ]]; then
	exit 1
fi
echo "✅ All dependencies found."
echo ""

echo -n "Enter proxy password for this session: "
read -rs PROXY_PASS
echo ""
export PROXY_PASS

# ==========================================
# Download & Verification Logic
# ==========================================

# Read the file line by line
while read -r url expected_checksum; do
	# Skip empty lines and lines starting with #
	[[ -z $url || $url == \#* ]] && continue

	filename=$(basename "$url")

	echo "========================================"
	echo "Processing: $filename"
	echo "========================================"

	# ---------------------------------------------------------
	# NEW: True Idempotency Check (Local First)
	# ---------------------------------------------------------
	if [[ -f $filename ]]; then
		echo "File already exists locally. Verifying checksum..."
		local_checksum=$(sha256sum "$filename" | awk '{print $1}')

		if [[ $local_checksum == "$expected_checksum" ]]; then
			echo "✅ Success: File already complete and verified. Skipping download."
			continue # Skips to the next URL in downloads.txt
		else
			echo "⚠️ Local file is incomplete or corrupted. Proceeding to download/resume..."
		fi
	fi
	# ---------------------------------------------------------

	actual_checksum=""

	# Loop continuously until the actual checksum matches the expected checksum
	until [[ $actual_checksum == "$expected_checksum" ]]; do
		echo "Starting download for $url..."
		./proxy-download.sh --url "$url"

		if [[ -f $filename ]]; then
			echo "Calculating checksum..."
			actual_checksum=$(sha256sum "$filename" | awk '{print $1}')

			if [[ $actual_checksum == "$expected_checksum" ]]; then
				echo "✅ Success: Checksum verified for $filename"
			else
				echo "❌ Checksum mismatch for $filename!"
				echo "   Removing bad file so 'wget -c' starts fresh..."
				rm -f "$filename"
				sleep 2
			fi
		else
			echo "⚠️ Download failed to produce $filename. Retrying in 5 seconds..."
			sleep 5
		fi
	done
done <"$CONFIG_FILE"

echo "🎉 All downloads have been successfully completed and verified!"
