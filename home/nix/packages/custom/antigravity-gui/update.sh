#!/usr/bin/env bash
#
# Antigravity GUI Nix Update Script
# Automatically fetches the latest release version, constructs URLs, calculates hashes, and writes to sources.json.
# Can be run via: nix-shell -p curl jq --run ./update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_JSON="$SCRIPT_DIR/sources.json"

UPDATER_URL="https://antigravity-hub-auto-updater-974169037036.us-central1.run.app"

echo "Fetching latest release list from updater..."
releases=$(curl -fsSL "$UPDATER_URL/releases")

# Extract the latest version and execution_id (first item in the JSON array)
version=$(echo "$releases" | jq -r '.[0].version')
execution_id=$(echo "$releases" | jq -r '.[0].execution_id')

echo "✓ Latest version detected: $version (Build: $execution_id)"

# Construct URLs
darwin_amd64_url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${execution_id}/darwin-x64/Antigravity.dmg"
darwin_arm64_url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${execution_id}/darwin-arm/Antigravity.dmg"
linux_amd64_url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${execution_id}/linux-x64/Antigravity.tar.gz"
linux_arm64_url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${execution_id}/linux-arm/Antigravity.tar.gz"

# Helper to fetch sha512 and convert it to hex format
get_sha512() {
	local url="$1"
	local name="$2"
	echo "Prefetching $name..." >&2
	local nix32_hash
	nix32_hash=$(nix-prefetch-url --type sha512 "$url")
	nix hash convert --hash-algo sha512 --from nix32 --to base16 "$nix32_hash"
}

darwin_amd64_hash=$(get_sha512 "$darwin_amd64_url" "x86_64-darwin")
darwin_arm64_hash=$(get_sha512 "$darwin_arm64_url" "aarch64-darwin")
linux_amd64_hash=$(get_sha512 "$linux_amd64_url" "x86_64-linux")
linux_arm64_hash=$(get_sha512 "$linux_arm64_url" "aarch64-linux")

# Construct the new sources.json
cat <<EOF >"$SOURCES_JSON"
{
  "version": "$version",
  "sources": {
    "x86_64-darwin": {
      "url": "$darwin_amd64_url",
      "sha512": "$darwin_amd64_hash"
    },
    "aarch64-darwin": {
      "url": "$darwin_arm64_url",
      "sha512": "$darwin_arm64_hash"
    },
    "x86_64-linux": {
      "url": "$linux_amd64_url",
      "sha512": "$linux_amd64_hash"
    },
    "aarch64-linux": {
      "url": "$linux_arm64_url",
      "sha512": "$linux_arm64_hash"
    }
  }
}
EOF

echo "✓ Successfully updated $SOURCES_JSON"
