#!/usr/bin/env bash

clear
set -euo pipefail

BLUETOOTH_CONTROLLER_COUNT=$(find /sys/class/bluetooth -mindepth 1 -maxdepth 1 | wc -l)

if [[ $BLUETOOTH_CONTROLLER_COUNT -gt 0 ]]; then

	BLUETOOTH_POWER=$(
		bluetoothctl show | grep -q 'Powered: yes$'
		echo "$?"
	)

	if [[ $BLUETOOTH_POWER -eq 0 ]]; then

		BLUETOOTH_CONNECTED_NAME=$(bluetoothctl devices Connected | sed -n -e 's/^Device \([[:xdigit:]]\{1,2\}:\)\{5\}[[:xdigit:]]\{1,2\} //p')
		BLUETOOTH_CONNECTED_MAC=$(bluetoothctl devices Connected | sed -n -e 's/^Device \(\([[:xdigit:]]\{1,2\}:\)\{5\}[[:xdigit:]]\{1,2\}\) .*/\1/p')
		BLUETOOTH_DEVICE_BATTERY=$(echo "info $BLUETOOTH_CONNECTED_MAC" | bluetoothctl | sed -n '/Battery Percentage:/ s/.*(\([0-9]*\).*/\1/p')

		if [[ $BLUETOOTH_CONNECTED_NAME != "" ]]; then
			echo " $BLUETOOTH_CONNECTED_NAME $BLUETOOTH_DEVICE_BATTERY%"
		else
			echo " None"
		fi

	else

		echo "󰂲 Off"

	fi

else

	echo "󰂲 No controller"

fi
