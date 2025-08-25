#!/usr/bin/env bash

set -euo pipefail

declare RESULT=" Error"
declare BLUETOOTH_CONTROLLER_COUNT=0
declare BLUETOOTH_POWER=0
declare BLUETOOTH_CONNECTED_NAME=""
declare BLUETOOTH_CONNECTED_MAC=""
declare BLUETOOTH_DEVICE_BATTERY=""

# Get the number of Bluetooth controllers
BLUETOOTH_CONTROLLER_COUNT=$(find /sys/class/bluetooth -mindepth 1 -maxdepth 1 | wc -l)

if [[ $BLUETOOTH_CONTROLLER_COUNT -gt 0 ]]; then

	# Get the power status of the Bluetooth controller
	BLUETOOTH_POWER=$(
		bluetoothctl show | grep -q 'Powered: yes$'
		echo "$?"
	)

	# If the Bluetooth controller is powered, get the connected device name, MAC address, and battery percentage
	if [[ $BLUETOOTH_POWER -eq 0 ]]; then

		BLUETOOTH_CONNECTED_NAME=$(bluetoothctl devices Connected | sed -n -e 's/^Device \([[:xdigit:]]\{1,2\}:\)\{5\}[[:xdigit:]]\{1,2\} //p')
		BLUETOOTH_CONNECTED_MAC=$(bluetoothctl devices Connected | sed -n -e 's/^Device \(\([[:xdigit:]]\{1,2\}:\)\{5\}[[:xdigit:]]\{1,2\}\) .*/\1/p')
		BLUETOOTH_DEVICE_BATTERY=$(echo "info $BLUETOOTH_CONNECTED_MAC" | bluetoothctl | sed -n '/Battery Percentage:/ s/.*(\([0-9]*\).*/\1/p')

		if [[ $BLUETOOTH_CONNECTED_NAME != "" ]]; then
			RESULT=" $BLUETOOTH_CONNECTED_NAME $BLUETOOTH_DEVICE_BATTERY%"
		else
			RESULT=" None"
		fi

	else

		RESULT="󰂲 Off"

	fi

else

	RESULT="󰂲 No controller"

fi

echo "$RESULT"
exit 0
