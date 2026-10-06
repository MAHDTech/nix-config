#!/usr/bin/env bash
set -euo pipefail

nixos-rebuild boot "$@"

staged_system=$(readlink -e /nix/var/nix/profiles/system)
booted_system=$(readlink -e /run/booted-system)
current_system=$(readlink -e /run/current-system)
if [[ $staged_system == "$booted_system" && $staged_system == "$current_system" ]]; then
	echo "System is already booted; skipping drain and reboot"
	exit 0
fi

attempt=""
cleanup() {
	local result=$?
	trap - EXIT
	if [[ -n $attempt ]]; then
		nixos-drain cancel --attempt "$attempt" || echo "Drain cancellation failed; operator intervention required" >&2
	fi
	exit "$result"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

attempt=$(nixos-drain drain --profile upgrade --owned)
if ! nixos-drain is-drained --attempt "$attempt"; then
	echo "Drain was cancelled or replaced; refusing to reboot" >&2
	exit 1
fi
if [[ $(readlink -e /nix/var/nix/profiles/system) != "$staged_system" ]]; then
	echo "Staged system changed during drain; refusing to reboot" >&2
	exit 1
fi
systemctl reboot --no-block
attempt=""
