#!/usr/bin/env bash

clear
set -euo pipefail

export RUSTDESK_PASSWORD="letmein"
export XDG_RUNTIME_DIR
XDG_RUNTIME_DIR=/run/user/$(id -u)

echo "Terminating any existing RustDesk instances..."
sudo pkill rustdesk || true
sleep 2

echo "Commanding Hyprland to launch RustDesk natively (via instance 0)..."
# Your magic bullet!
hyprctl --instance 0 dispatch exec "rustdesk"

echo "Waiting for RustDesk GUI to initialize (5 seconds)..."
sleep 5

echo "Setting RustDesk password..."
sudo rustdesk --password "${RUSTDESK_PASSWORD}" >/dev/null 2>&1

echo "Retrieving RustDesk ID..."
RUSTDESK_ID=$(sudo rustdesk --get-id | tail -n 1)

echo ""
echo "========================================"
echo "✅ RustDesk is ready for connections!"
echo "   ID: ${RUSTDESK_ID}"
echo "   Password: ${RUSTDESK_PASSWORD}"
echo "========================================"
echo ""
