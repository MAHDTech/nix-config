#!/usr/bin/env bash

# Default values
CHUNK_SIZE="1G"
CONFIG_FILE="downloads.txt"
ACTION="split"

# 1. Parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--chunk-size)
		CHUNK_SIZE="$2"
		shift
		;;
	--config)
		CONFIG_FILE="$2"
		shift
		;;
	--action)
		ACTION="$2"
		shift
		;;
	*)
		echo "Error: Unknown parameter passed: $1"
		echo "Usage: ./splitter.sh [--action split|join] [--chunk-size 1G] [--config downloads.txt]"
		exit 1
		;;
	esac
	shift
done

# Validate action
if [[ $ACTION != "split" && $ACTION != "join" ]]; then
	echo "❌ Error: Invalid action '$ACTION'. Must be 'split' or 'join'."
	exit 1
fi

if [[ ! -f $CONFIG_FILE ]]; then
	echo "❌ Error: Configuration file '$CONFIG_FILE' not found."
	exit 1
fi

# 2. Dependency Check (added 'cat' for joining)
REQ_DEPS=(sha256sum awk split cat)
for cmd in "${REQ_DEPS[@]}"; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "❌ Error: Required command '$cmd' is not installed."
		exit 1
	fi
done

echo "========================================"
echo " Starting Mode : $(echo "$ACTION" | tr '[:lower:]' '[:upper:]')"
if [[ $ACTION == "split" ]]; then
	echo " Chunk Size    : $CHUNK_SIZE"
fi
echo "========================================"
echo ""

# 3. Read config and process
while read -r url expected_checksum; do
	# Skip empty lines and comments
	[[ -z $url || $url == \#* ]] && continue

	filename=$(basename "$url")
	PREFIX="${filename}.part-"

	echo "----------------------------------------"
	echo "Target: $filename"
	echo "----------------------------------------"

	if [[ $ACTION == "split" ]]; then

		# Check if original file exists
		if [[ ! -f $filename ]]; then
			echo "⚠️  File $filename not found in directory. Skipping."
			continue
		fi

		# Verify checksum before splitting
		echo "Verifying checksum before splitting..."
		actual_checksum=$(sha256sum "$filename" | awk '{print $1}')

		if [[ $actual_checksum != "$expected_checksum" ]]; then
			echo "❌ Error: Checksum mismatch for $filename. Cannot safely split."
			echo "   Expected: $expected_checksum"
			echo "   Got:      $actual_checksum"
			continue
		fi

		echo "✅ Checksum matched. Splitting file..."

		# Execute the split command
		split -b "$CHUNK_SIZE" -d "$filename" "$PREFIX" || {
			echo "❌ Error: Failed to split $filename."
			continue
		}

		echo "✅ Successfully split into chunks:"
		for part in "${PREFIX}"*; do
			size=$(du -h "$part" | cut -f1)
			echo "   $size $part"
		done

	elif [[ $ACTION == "join" ]]; then

		# Safely check if part files exist without printing raw glob characters if missing
		shopt -s nullglob
		parts=("${PREFIX}*")
		shopt -u nullglob

		if [[ ${#parts[@]} -eq 0 ]]; then
			echo "⚠️  No split parts found matching '${PREFIX}*'. Skipping."
			continue
		fi

		echo "Found ${#parts[@]} parts. Joining..."

		# Cat the parts back together into the original filename
		# Because we used numeric suffixes (-d) with split, bash expansion sorts them perfectly
		cat "${PREFIX}"* >"$filename" || {
			echo "❌ Error: Failed to write the joined file $filename."
			continue
		}

		echo "Verifying checksum of reassembled file..."
		actual_checksum=$(sha256sum "$filename" | awk '{print $1}')

		if [[ $actual_checksum == "$expected_checksum" ]]; then
			echo "✅ Success: File joined correctly and checksum verified!"
		else
			echo "❌ Error: Checksum mismatch on the joined file!"
			echo "   This usually means a part is missing or corrupted."
			echo "   Expected: $expected_checksum"
			echo "   Got:      $actual_checksum"
		fi

	fi

done <"$CONFIG_FILE"

echo ""
echo "🎉 Operation '$ACTION' complete."
