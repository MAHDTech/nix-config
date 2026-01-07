#!/usr/bin/env bash

set -uo pipefail

# Host to ping
HOST="1.1.1.1"

# Icon (Tachometer)
ICON=""

# Ping command
# -c 1: count 1
# -W 1: timeout 1 second
# We capture the output and extract the time value.
# The `if` statement checks if the entire pipeline succeeds.
if latency=$(ping -c 1 -W 1 "$HOST" 2>/dev/null | grep "time=" | sed -E 's/.*time=([0-9.]+).*/\1/'); then
	echo "$ICON ${latency}ms"
else
	echo "$ICON Timeout"
fi
