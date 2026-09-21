#!/usr/bin/env bash
# Build the generic cloud bootstrap image from the repository's pinned inputs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"
cloud="${1:-}"
if [[ -z $cloud ]]; then
	PS3="Select cloud image: "
	select cloud in qemu; do
		[[ -n $cloud ]] && break
		echo "Choose a listed image." >&2
	done
fi
if [[ $cloud != qemu ]]; then
	echo "Supported image: qemu. VMware support is deferred." >&2
	exit 1
fi
mkdir -p output
out="output/nixos-${cloud}.img"
tmp="$(mktemp "output/.nixos-${cloud}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
nix build ".#${cloud}-image" --accept-flake-config --out-link "result-cloud-${cloud}"
if command -v qemu-img >/dev/null 2>&1; then
	QEMU_IMG=(qemu-img)
else
	QEMU_IMG=(nix shell --inputs-from . nixpkgs#qemu-utils --command qemu-img)
fi
"${QEMU_IMG[@]}" convert -c -f qcow2 -O qcow2 "result-cloud-${cloud}/nixos-qemu.qcow2" "$tmp"
mv -f "$tmp" "$out"
echo "Created $out (qcow2, x86_64, UEFI)."
echo "Supply cloud-init with /etc/nixos-bootstrap/bootstrap.yaml and operator SSH public keys."
echo "The guest waits for prerequisite files, then builds and reboots; no secrets belong in user-data."
