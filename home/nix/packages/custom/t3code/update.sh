#!/usr/bin/env nix-shell
#shellcheck disable=SC1008
#!nix-shell -i bash -p bash curl jq gnused gnugrep nix cacert
#
# T3 Code Nix Update Script
# Bumps unwrapped.nix to the latest stable upstream release (or the version
# given as $1, e.g. "0.0.39" or "0.0.40-nightly.20260907.1346"), then
# refreshes every pinned hash:
#   - src hash        (fetchFromGitHub, unwrapped.nix)
#   - pnpmDeps hash   (fetchPnpmDeps, unwrapped.nix)
#   - cargoHash       (resource-monitor.nix)
# The last two are harvested from fake-hash builds against this repo's
# pinned nixpkgs, so they match what the real build will see.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOST="${HOST_NAME:-$(hostname)}"

gh_curl() {
	curl ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} -fsSL "$@"
}

if [ $# -ge 1 ]; then
	VERSION="${1#v}"
else
	# releases/latest skips prereleases (nightlies) by definition.
	VERSION=$(gh_curl "https://api.github.com/repos/pingdotgg/t3code/releases/latest" |
		jq -r '.tag_name' | sed 's/^v//')
fi
TAG="v$VERSION"

CURRENT=$(sed -nE 's/^    version = "(.*)";$/\1/p' unwrapped.nix)
if [ "$CURRENT" == "$VERSION" ]; then
	echo "t3code: already at $VERSION"
	exit 0
fi
echo "t3code: $CURRENT -> $VERSION"

FAKE="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
PKGS="(builtins.getFlake \"$REPO_ROOT\").nixosConfigurations.\"$HOST\".pkgs"

# Build the given attribute of an expression with a fake hash and return the
# hash Nix reports it actually got. Only the fetcher runs, not the full build.
harvest_hash() {
	local expr="$1"
	local log hash
	set +e
	log=$(nix --extra-experimental-features 'nix-command flakes' build --no-link \
		--accept-flake-config --impure --expr "$expr" 2>&1)
	set -e
	hash=$(echo "$log" | sed -nE 's/^\s*got:\s*(sha256-\S+).*$/\1/p' | head -n1)
	if [ -z "$hash" ]; then
		echo "t3code: failed to extract hash from build output:" >&2
		echo "$log" | tail -n 30 >&2
		exit 1
	fi
	echo "$hash"
}

# --- src hash ---------------------------------------------------------------
echo "t3code: prefetching source"
SRC_HASH=$(nix-prefetch-url --unpack --type sha256 \
	"https://github.com/pingdotgg/t3code/archive/refs/tags/$TAG.tar.gz" 2>/dev/null |
	xargs nix-hash --to-sri --type sha256)

sed -i -E \
	-e "s|^    version = \".*\";$|    version = \"$VERSION\";|" \
	-e "/src = fetchFromGitHub \{/,/\};/ s|hash = \"sha256-.*\";|hash = \"$SRC_HASH\";|" \
	-e "/pnpmDeps = fetchPnpmDeps \{/,/\};/ s|hash = \"sha256-.*\";|hash = \"$FAKE\";|" \
	unwrapped.nix

# --- pnpmDeps hash ------------------------------------------------------------
echo "t3code: computing pnpmDeps hash (fake-hash build)"
PNPM_HASH=$(harvest_hash "let pkgs = $PKGS; in (pkgs.callPackage $PWD/unwrapped.nix { }).pnpmDeps")
sed -i -E \
	-e "/pnpmDeps = fetchPnpmDeps \{/,/\};/ s|hash = \"sha256-.*\";|hash = \"$PNPM_HASH\";|" \
	unwrapped.nix

# --- cargoHash (resource monitor) -------------------------------------------
echo "t3code: computing resource-monitor cargoHash (fake-hash build)"
sed -i -E "s|^  cargoHash = \"sha256-.*\";$|  cargoHash = \"$FAKE\";|" resource-monitor.nix
CARGO_HASH=$(harvest_hash "let pkgs = $PKGS; in (pkgs.callPackage $PWD/resource-monitor.nix {
	t3code-unwrapped = pkgs.callPackage $PWD/unwrapped.nix { }; }).cargoDeps")
sed -i -E "s|^  cargoHash = \"sha256-.*\";$|  cargoHash = \"$CARGO_HASH\";|" resource-monitor.nix

echo "t3code: updated to $VERSION"
echo "  src hash:   $SRC_HASH"
echo "  pnpmDeps:   $PNPM_HASH"
echo "  cargoHash:  $CARGO_HASH"
