#!/usr/bin/env bash
set -euo pipefail

mode=${1:?}
shift
units=("$@")
state=${SERVICE_DRAIN_STATE:?}

case "$mode" in
drain)
	umask 077
	# Service users must be able to test the gate without reading restore state.
	install -d -m 0755 "$state"
	if [[ ! -e $state/restore ]]; then
		for unit in "${units[@]}"; do
			active=$(systemctl show "$unit" --property=ActiveState --value)
			if [[ $active == active || $active == activating || $active == reloading ]]; then
				printf '%s\n' "$unit"
			fi
		done >"$state/restore"
	fi
	touch "$state/blocked"
	for unit in "${units[@]}"; do
		echo "Draining $unit"
		systemctl stop "$unit"
		if [[ $unit == *.service ]]; then
			result=$(systemctl show "$unit" --property=Result --value)
			if [[ $result != success ]]; then
				echo "$unit did not stop cleanly: $result" >&2
				exit 1
			fi
		fi
	done
	;;
cancel)
	[[ -e $state/restore ]] || exit 0
	rm -f "$state/blocked"
	for ((i = ${#units[@]} - 1; i >= 0; i--)); do
		unit=${units[i]}
		if grep -Fxq -- "$unit" "$state/restore"; then
			echo "Resuming $unit"
			systemctl start "$unit"
		fi
	done
	rm "$state/restore"
	rmdir "$state"
	;;
*) exit 2 ;;
esac
