#!/usr/bin/env nix-shell
#shellcheck disable=SC1008
#!nix-shell -i bash -p bash curl jq yq-go cacert

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_JSON="$SCRIPT_DIR/sources.json"
REPO="wakatime/desktop-wakatime"

echo "Checking latest release for ${REPO}..."

if [ $# -ge 1 ]; then
	TAG="$1"
else
	# Follow redirect to get latest release tag
	REDIRECT_URL=$(curl -sIL -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest" || true)
	LATEST_TAG="${REDIRECT_URL##*/}"

	if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "latest" ]; then
		LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)
	fi
	TAG="$LATEST_TAG"
fi

if [[ $TAG != v* ]]; then
	TAG="v$TAG"
fi

VERSION="${TAG#v}"

# Check if already up to date (unless FORCE=1)
if [ "${FORCE:-0}" != "1" ] && [ -f "$SOURCES_JSON" ]; then
	CURRENT_VERSION=$(jq -r '.version // empty' "$SOURCES_JSON" 2>/dev/null || true)
	CURRENT_TAG=$(jq -r '.tag // empty' "$SOURCES_JSON" 2>/dev/null || true)
	if [ "$CURRENT_TAG" = "$TAG" ] && [ "$CURRENT_VERSION" = "$VERSION" ]; then
		echo "wakatime-desktop: already up-to-date at ${TAG}"
		exit 0
	fi
fi

echo "Updating wakatime-desktop to ${TAG} (version ${VERSION})..."

# GitHub releases encode '+' as '%2B' in asset URLs
ENCODED_TAG="${TAG//+/%2B}"
DOWNLOAD_BASE_URL="https://github.com/${REPO}/releases/download/${ENCODED_TAG}"

echo "Fetching release manifests from ${DOWNLOAD_BASE_URL}..."
YAML_X86=$(curl -fsSL "${DOWNLOAD_BASE_URL}/latest-linux.yml")
YAML_ARM=$(curl -fsSL "${DOWNLOAD_BASE_URL}/latest-linux-arm64.yml")

# Parse manifests to JSON using yq-go
JSON_X86=$(echo "$YAML_X86" | yq -o=json)
JSON_ARM=$(echo "$YAML_ARM" | yq -o=json)

# Extract asset file name and sha512 hash
FILE_X86=$(echo "$JSON_X86" | jq -r '.path // .files[0].url')
SHA512_X86=$(echo "$JSON_X86" | jq -r '.sha512 // .files[0].sha512')

FILE_ARM=$(echo "$JSON_ARM" | jq -r '.path // .files[0].url')
SHA512_ARM=$(echo "$JSON_ARM" | jq -r '.sha512 // .files[0].sha512')

if [ -z "$FILE_X86" ] || [ -z "$SHA512_X86" ]; then
	echo "Error: failed to parse x86_64 release manifest" >&2
	exit 1
fi

if [ -z "$FILE_ARM" ] || [ -z "$SHA512_ARM" ]; then
	echo "Error: failed to parse arm64 release manifest" >&2
	exit 1
fi

URL_X86="${DOWNLOAD_BASE_URL}/${FILE_X86}"
HASH_X86="sha512-${SHA512_X86}"

URL_ARM="${DOWNLOAD_BASE_URL}/${FILE_ARM}"
HASH_ARM="sha512-${SHA512_ARM}"

jq -n \
	--arg version "$VERSION" \
	--arg tag "$TAG" \
	--arg url_x86 "$URL_X86" \
	--arg hash_x86 "$HASH_X86" \
	--arg url_arm "$URL_ARM" \
	--arg hash_arm "$HASH_ARM" \
	'{
    version: $version,
    tag: $tag,
    sources: {
      "x86_64-linux": {
        url: $url_x86,
        hash: $hash_x86
      },
      "aarch64-linux": {
        url: $url_arm,
        hash: $hash_arm
      }
    }
  }' >"$SOURCES_JSON"

echo "✓ Successfully updated sources.json to ${VERSION} (${TAG})"
