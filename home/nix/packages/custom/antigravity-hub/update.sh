#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix coreutils
# shellcheck shell=bash

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SOURCE_JSON="$DIR/sources.json"

API_URL="https://antigravity-auto-updater-974169037036.us-central1.run.app/releases"

# Fetch data and find the actual highest version
JSON_DATA=$(curl -s "$API_URL")
NEW_VERSION=$(echo "$JSON_DATA" | jq -r '.[].version' | sort -V | tail -n 1)
NEW_EXEC_ID=$(echo "$JSON_DATA" | jq -r --arg ver "$NEW_VERSION" '.[] | select(.version == $ver) | .execution_id')

# Check if we actually need to update
if [[ -f $SOURCE_JSON ]]; then
	CURRENT_VERSION=$(jq -r '.version' "$SOURCE_JSON")
	if [[ $CURRENT_VERSION == "$NEW_VERSION" ]]; then
		echo "Antigravity Hub is already up to date ($CURRENT_VERSION)"
		exit 0
	fi
fi

echo "Updating Antigravity Hub to $NEW_VERSION (exec id $NEW_EXEC_ID)..."

URL_X64="https://storage.googleapis.com/antigravity-public/antigravity-hub/${NEW_VERSION}-${NEW_EXEC_ID}/linux-x64/Antigravity.tar.gz"
URL_ARM="https://storage.googleapis.com/antigravity-public/antigravity-hub/${NEW_VERSION}-${NEW_EXEC_ID}/linux-arm/Antigravity.tar.gz"

echo "Fetching hash for x86_64-linux..."
HASH_X64=$(nix-prefetch-url "$URL_X64")
HASH_X64_SRI=$(nix hash to-sri --type sha256 "$HASH_X64")

echo "Fetching hash for aarch64-linux..."
HASH_ARM=$(nix-prefetch-url "$URL_ARM")
HASH_ARM_SRI=$(nix hash to-sri --type sha256 "$HASH_ARM")

jq -n \
	--arg ver "$NEW_VERSION" \
	--arg url_x64 "$URL_X64" \
	--arg hash_x64 "$HASH_X64_SRI" \
	--arg root_x64 "Antigravity-x64" \
	--arg url_arm "$URL_ARM" \
	--arg hash_arm "$HASH_ARM_SRI" \
	--arg root_arm "Antigravity-arm64" \
	'{
    version: $ver,
    sources: {
      "x86_64-linux": { url: $url_x64, sha256: $hash_x64, sourceRoot: $root_x64 },
      "aarch64-linux": { url: $url_arm, sha256: $hash_arm, sourceRoot: $root_arm }
    }
  }' >"$SOURCE_JSON"

echo "Successfully updated sources.json to $NEW_VERSION."
