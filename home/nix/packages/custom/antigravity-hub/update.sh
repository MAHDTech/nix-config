#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix coreutils
# shellcheck shell=bash

clear
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SOURCE_JSON="$DIR/sources.json"

echo "Fetching latest version from Cloud Run updater API..."
# 1. Get the latest release version and execution ID (ignoring test version 100.x)
LATEST_RELEASE=$(curl -fsSL "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases" |
	jq -r '.[] | "\(.version)-\(.execution_id)"' |
	grep -v '^100\.' |
	sort -V |
	tail -n 1)

VERSION=$(echo "$LATEST_RELEASE" | cut -d- -f1)
EXEC_ID=$(echo "$LATEST_RELEASE" | cut -d- -f2)

# Check if we actually need to update
if [[ -f $SOURCE_JSON ]]; then
	CURRENT_VERSION=$(jq -r '.version' "$SOURCE_JSON")
	if [[ $CURRENT_VERSION == "$VERSION" ]]; then
		echo "Antigravity Hub is already up to date ($CURRENT_VERSION)"
		exit 0
	fi
fi

echo "Updating Antigravity Hub to $VERSION (exec id $EXEC_ID)..."

# 2. Fetch platform manifests containing pre-calculated hashes
fetch_manifest() {
	local platform_path="$1"
	curl -fsSL "https://storage.googleapis.com/antigravity-public/antigravity-hub/${VERSION}-${EXEC_ID}/${platform_path}/manifest.json"
}

echo "Fetching platform manifests..."
linux_amd64=$(fetch_manifest "linux-x64")
linux_arm64=$(fetch_manifest "linux-arm")

# Convert hex sha256 from GCS manifest to standard Nix SRI format
convert_hash() {
	local hex="$1"
	nix hash convert --to sri "sha256:$hex"
}

hash_x64=$(convert_hash "$(echo "$linux_amd64" | jq -r '.sha256hash')")
hash_arm=$(convert_hash "$(echo "$linux_arm64" | jq -r '.sha256hash')")

# 3. Write sources.json
jq -n \
	--arg ver "$VERSION" \
	--arg url_x64 "$(echo "$linux_amd64" | jq -r '.url')" \
	--arg hash_x64 "$hash_x64" \
	--arg root_x64 "Antigravity-x64" \
	--arg url_arm "$(echo "$linux_arm64" | jq -r '.url')" \
	--arg hash_arm "$hash_arm" \
	--arg root_arm "Antigravity-arm64" \
	'{
    version: $ver,
    sources: {
      "x86_64-linux": { url: $url_x64, sha256: $hash_x64, sourceRoot: $root_x64 },
      "aarch64-linux": { url: $url_arm, sha256: $hash_arm, sourceRoot: $root_arm }
    }
  }' >"$SOURCE_JSON"

echo "Successfully updated sources.json to $VERSION."
