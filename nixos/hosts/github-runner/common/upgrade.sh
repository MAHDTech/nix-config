#!/usr/bin/env bash
set -euo pipefail

nixos-rebuild boot \
	--flake "${RUNNER_FLAKE:?}#${RUNNER_HOST:?}" --accept-flake-config --show-trace --refresh

staged_system=$(readlink -e /nix/var/nix/profiles/system)
booted_system=$(readlink -e /run/booted-system)
current_system=$(readlink -e /run/current-system)
if [[ $staged_system == "$booted_system" && $staged_system == "$current_system" ]]; then
	echo "Runner system is already booted; skipping drain and reboot"
	exit 0
fi

nixos-drain drain --profile upgrade
systemctl reboot --no-block
