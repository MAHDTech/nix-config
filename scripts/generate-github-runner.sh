#!/usr/bin/env bash

#########################
# Name: generate-github-runner.sh
# Description: Generates the latest generic vanilla GitHub Runner qcow2 image.
#########################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

DATE_TAG="$(date +%Y%m%d)"
DEFAULT_OUTPUT_DIR="output"
DEFAULT_OUTPUT="${DEFAULT_OUTPUT_DIR}/github-runner-${DATE_TAG}.qcow2"
OUTPUT_FILE="${1:-${DEFAULT_OUTPUT}}"
OUT_LINK="result-github-runner"

mkdir -p ${DEFAULT_OUTPUT_DIR} || true

echo "========================================================"
echo " Building generic vanilla GitHub Runner image"
echo " Flake target: .#github-runner-image"
echo " Target output: ${OUTPUT_FILE}"
echo "========================================================"

# Locate or provision qemu-img
if command -v qemu-img >/dev/null 2>&1; then
	QEMU_IMG=(qemu-img)
else
	echo "qemu-img not found in PATH, using nixpkgs#qemu-utils..."
	QEMU_IMG=(nix run --extra-experimental-features "nix-command flakes" nixpkgs#qemu-utils -- qemu-img)
fi

echo ""
echo "[1/2] Building qemu-efi image with Nix..."
nix build .#github-runner-image --accept-flake-config --out-link "${OUT_LINK}"

if [ -f "${OUT_LINK}/nixos.qcow2" ]; then
	SRC_IMG="${OUT_LINK}/nixos.qcow2"
else
	SRC_IMG="$(find "${OUT_LINK}" -maxdepth 1 -name "*.qcow2" | head -n 1)"
fi

if [ -z "${SRC_IMG:-}" ] || [ ! -f "${SRC_IMG}" ]; then
	echo "Error: Built artifact not found in ${OUT_LINK}." >&2
	exit 1
fi

echo ""
echo "[2/2] Compressing image to ${OUTPUT_FILE}..."
"${QEMU_IMG[@]}" convert -c -O qcow2 "${SRC_IMG}" "${OUTPUT_FILE}"

FILE_SIZE="$(du -h "${OUTPUT_FILE}" | cut -f1)"

echo ""
echo "========================================================"
echo " Image generation complete!"
echo " Output: ${OUTPUT_FILE} (${FILE_SIZE})"
echo "========================================================"
echo ""
echo "Next steps:"
echo " 1. Upload ${OUTPUT_FILE} to the Caddy images mirror."
echo " 2. Update image reference in docs/runbooks/github-runners.md (in bingamon-lab/lz-paas)."
echo " 3. When deployed, cloud-init will set hostname (github-runner-XX) and"
echo "    the VM will automatically bootstrap to that runner host configuration."
