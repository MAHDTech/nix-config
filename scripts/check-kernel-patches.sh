#!/usr/bin/env bash

# This script checks the status of local Zenbook patches against a target kernel source directory.
# Usage: ./check-kernel-patches.sh <path-to-kernel-source>

set -euo pipefail

# Find directory of this script to locate patches directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "${SCRIPT_DIR}/../nixos/hosts/zenbook/files/patches" 2>/dev/null && pwd || echo "")"

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <path-to-kernel-source-directory>"
	exit 1
fi

KERNEL_DIR="$1"

if [[ ! -d $KERNEL_DIR ]]; then
	echo "Error: Directory '$KERNEL_DIR' does not exist."
	exit 1
fi

if [[ -z $PATCH_DIR || ! -d $PATCH_DIR ]]; then
	echo "Error: Patch directory not found."
	exit 1
fi

echo "Checking patches in: $PATCH_DIR"
echo "Against kernel tree: $KERNEL_DIR"
echo "--------------------------------------------------"

merged=0
pending=0
conflict=0

# Ensure we're in the kernel directory when running the patch test
cd "$KERNEL_DIR"

for patch_path in "$PATCH_DIR"/*.patch; do
	[[ -e $patch_path ]] || continue
	patch_name="$(basename "$patch_path")"

	# 1. Check if already merged (reverse dry-run succeeds)
	if patch -p1 --dry-run --reverse --force <"$patch_path" >/dev/null 2>&1; then
		echo -e "\033[0;32m[MERGED]\033[0m   $patch_name"
		merged=$((merged + 1))
	# 2. Check if it applies cleanly forward
	elif patch -p1 --dry-run --force <"$patch_path" >/dev/null 2>&1; then
		echo -e "\033[0;34m[PENDING]\033[0m  $patch_name"
		pending=$((pending + 1))
	# 3. Otherwise it's a conflict
	else
		echo -e "\033[0;31m[CONFLICT]\033[0m $patch_name"
		conflict=$((conflict + 1))
	fi
done

echo "--------------------------------------------------"
echo "Summary: $merged merged, $pending pending, $conflict conflicts."

if [[ $conflict -gt 0 ]]; then
	exit 2
fi
