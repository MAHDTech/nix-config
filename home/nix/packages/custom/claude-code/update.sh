#!/usr/bin/env nix-shell
#shellcheck disable=SC1008
#!nix-shell -i bash -p bash curl cacert
#
# Claude Code Nix Update Script
# Fetches the release manifest (version + per-platform checksums) for the
# latest version, or the version given as $1, and writes manifest.json.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BASE_URL="https://downloads.claude.ai/claude-code-releases"

VERSION="${1:-$(curl -fsSL "$BASE_URL/latest")}"

curl -fsSL "$BASE_URL/$VERSION/manifest.json" --output manifest.json
