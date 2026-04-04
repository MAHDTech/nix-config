# ASUS Zenbook Snapdragon X Elite - NixOS "McGuyver" Install Guide

This guide is for installing NixOS from a RAM-based `kexec` environment.

## 1. Networking
If WiFi doesn't connect automatically, use `nmcli` or `wpa_supplicant`.

### Plan B: USB Tethering
1. Connect your Android phone via USB.
2. Enable "USB Tethering" on the phone.
3. The installer should automatically see the `usb0` interface.
4. Verify with `ip addr`.

## 2. Partitioning with Disko
The configuration uses `disko` to automate Btrfs subvolume creation.
**WARNING: This will wipe /dev/nvme0n1.**

```bash
# Run disko to format and mount everything
disko --mode disko /etc/nixos/nixos/hosts/zenbook/disko-config.nix
```

## 3. Final Installation
The partitions are now mounted at `/mnt`.

```bash
# Install the system
nixos-install --flake .#ZENBOOK
```

## 4. Troubleshooting
- **No Sound:** Check if `ALSA_CONFIG_UCM2` is set to `/etc/alsa/ucm2`.
- **No WiFi:** Ensure your phone is tethered or try `nmtui`.
