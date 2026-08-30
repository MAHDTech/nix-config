#!/usr/bin/env nix-shell
#shellcheck disable=SC1008
#!nix-shell -i bash -p bash curl jq nix cacert
#
# Antigravity Hub Nix Update Script
# Fetches the latest release from the Cloud Run updater API, prefetches the
# platform tarballs into the Nix store to compute their hashes, and writes
# sources.json. Upstream no longer publishes per-platform manifest.json files,
# so hashes must be computed locally.

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

# 2. Prefetch each platform tarball to compute its SRI sha256
tarball_url() {
	local platform_path="$1"
	echo "https://storage.googleapis.com/antigravity-public/antigravity-hub/${VERSION}-${EXEC_ID}/${platform_path}/Antigravity.tar.gz"
}

prefetch_hash() {
	local url="$1"
	nix store prefetch-file --json "$url" | jq -r '.hash'
}

url_x64=$(tarball_url "linux-x64")
url_arm=$(tarball_url "linux-arm")

echo "Prefetching linux-x64 tarball (this downloads ~170MB)..."
hash_x64=$(prefetch_hash "$url_x64")

echo "Prefetching linux-arm tarball (this downloads ~170MB)..."
hash_arm=$(prefetch_hash "$url_arm")

# 3. Write sources.json
jq -n \
	--arg ver "$VERSION" \
	--arg url_x64 "$url_x64" \
	--arg hash_x64 "$hash_x64" \
	--arg root_x64 "Antigravity-x64" \
	--arg url_arm "$url_arm" \
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
