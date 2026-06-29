#!/usr/bin/env bash
#
# Antigravity CLI Nix Update Script
# Automatically fetches the latest manifests directly from Google Cloud Storage,
# extracts versions/hashes, and writes to sources.json.
# Can be run via: nix-shell -p curl jq --run ./update.sh

clear
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_JSON="$SCRIPT_DIR/sources.json"

echo "Fetching latest version from Cloud Run updater API..."
# Find the latest release version and execution ID
LATEST_RELEASE=$(curl -fsSL "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/releases" |
	jq -r '.[] | "\(.version)-\(.execution_id)"' |
	grep -v '^100\.' |
	sort -V |
	tail -n 1)

VERSION=$(echo "$LATEST_RELEASE" | cut -d- -f1)
EXEC_ID=$(echo "$LATEST_RELEASE" | cut -d- -f2)

echo "✓ Latest version detected: $VERSION-$EXEC_ID"

# Helper to fetch platform manifest containing sha512 hash and url
fetch_manifest() {
	local platform_path="$1"
	curl -fsSL "https://storage.googleapis.com/antigravity-public/antigravity-cli/${VERSION}-${EXEC_ID}/${platform_path}/manifest.json"
}

echo "Fetching platform manifests..."
darwin_x64=$(fetch_manifest "darwin-x64")
darwin_arm64=$(fetch_manifest "darwin-arm")
linux_x64=$(fetch_manifest "linux-x64")
linux_arm64=$(fetch_manifest "linux-arm")

# Extract URLs and standard Nix hashes
darwin_x64_url=$(echo "$darwin_x64" | jq -r '.url')
darwin_x64_hash=$(echo "$darwin_x64" | jq -r '.sha512')

darwin_arm64_url=$(echo "$darwin_arm64" | jq -r '.url')
darwin_arm64_hash=$(echo "$darwin_arm64" | jq -r '.sha512')

linux_x64_url=$(echo "$linux_x64" | jq -r '.url')
linux_x64_hash=$(echo "$linux_x64" | jq -r '.sha512')

linux_arm64_url=$(echo "$linux_arm64" | jq -r '.url')
linux_arm64_hash=$(echo "$linux_arm64" | jq -r '.sha512')

# Construct the new sources.json
jq -n \
	--arg ver "$VERSION" \
	--arg darwin_x64_url "$darwin_x64_url" \
	--arg darwin_x64_hash "$darwin_x64_hash" \
	--arg darwin_arm64_url "$darwin_arm64_url" \
	--arg darwin_arm64_hash "$darwin_arm64_hash" \
	--arg linux_x64_url "$linux_x64_url" \
	--arg linux_x64_hash "$linux_x64_hash" \
	--arg linux_arm64_url "$linux_arm64_url" \
	--arg linux_arm64_hash "$linux_arm64_hash" \
	'{
    "version": $ver,
    "sources": {
      "x86_64-darwin": {
        "url": $darwin_x64_url,
        "sha512": $darwin_x64_hash
      },
      "aarch64-darwin": {
        "url": $darwin_arm64_url,
        "sha512": $darwin_arm64_hash
      },
      "x86_64-linux": {
        "url": $linux_x64_url,
        "sha512": $linux_x64_hash
      },
      "aarch64-linux": {
        "url": $linux_arm64_url,
        "sha512": $linux_arm64_hash
      }
    }
  }' >"$SOURCES_JSON"

echo "✓ Successfully updated sources.json to $VERSION"
