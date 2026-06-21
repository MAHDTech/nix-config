# CloudKey Gen2 Plus — Recovery & Flashing Guide

This document covers the recovery, flashing, and debugging workflow for running
NixOS on the Ubiquiti CloudKey Gen2 Plus (APQ8053).

## Prerequisites

| Item                   | Details                                                        |
| ---------------------- | -------------------------------------------------------------- |
| CloudKey IP (recovery) | `10.10.200.200` (DHCP reservation for MAC `74:83:c2:7b:82:9f`) |
| Server IP              | `10.10.1.93` (JONS — the build machine)                        |
| HTTP port              | `16000` (Python HTTP server)                                   |
| Netcat port            | `16000` (ramoops dump receiver)                                |
| Recovery credentials   | `root` / `ubnt`                                                |

## Quick Start

### 1. Build the installer

```bash
cd /boot/nixos/nix-config
nix build .#installer-bootycall
# Output: ./result/boot.img and ./result/rootfs.iso
```

### 2. Start the HTTP server

```bash
cd /boot/nixos/nix-config
python3 -m http.server 16000
```

### 3. Boot CloudKey into recovery mode

1. Power off the CloudKey
2. Hold the reset button with a paperclip
3. Power it on while holding reset
4. Hold until the LED flashes white/blue (~10 seconds)
5. Release — the CloudKey boots into recovery at `10.10.200.200`

### 4. Flash with the automated script

```bash
nix-shell -p expect --run "./nixos/hosts/bootycall/scripts/flash-recovery.exp 10.10.200.200 10.10.1.93 16000"
```

The script will:

- Telnet into recovery as `root`
- Flash `rootfs.iso` → `/dev/mmcblk0p46` (userdata partition)
- Flash `boot.img` → `/dev/mmcblk0p42` (boot partition)
- Sync and reboot

### 5. Wait for NixOS to boot

After reboot, wait 3–4 minutes for the full boot sequence:

- Stage-1 (scripted initrd): mounts ISO, squashfs, overlay
- Stage-2 (systemd): starts services, DHCP, SSH

Check your router's DHCP lease table for MAC `74:83:c2:7b:82:9f`.

---

## Capturing Ramoops Dumps

If the system fails to boot (no DHCP after 5 minutes), capture a ramoops dump
for debugging.

### Automated capture

Start a netcat listener first, then run the capture script:

```bash
# Terminal 1: Start listener
nc -l -p 16000 > /tmp/dumpNN.bin

# Terminal 2: Capture dump
nix-shell -p expect --run "./nixos/hosts/bootycall/scripts/capture-dump.exp 10.10.200.200 10.10.1.93 16000"
```

### Analyzing the dump

```bash
# Quick scan for key events
strings /tmp/dumpNN.bin | grep -iE "usb|mount|fail|error|panic|eth0|dhcp|stage-1"
```

### What the ramoops dump contains

The ramoops region lives at physical address `0x92000000` (2 MiB). The recovery
kernel doesn't have `pstore` so we read `/dev/mem` directly:

```
dd if=/dev/mem bs=512 skip=4784128 count=4096
                              │          │
                              │          └─ 4096 × 512 = 2 MiB
                              └─ 4784128 × 512 = 0x92000000
```

The dump contains the kernel ring buffer (`dmesg`) from the **previous** boot,
including any panic traces. Records may be zlib-compressed with
`====<timestamp>-C` headers.

---

## Manual Flashing (without expect)

If the expect scripts don't work, flash manually via telnet:

```bash
telnet 10.10.200.200
# Login: root / ubnt

# Flash rootfs.iso
umount /dev/mmcblk0p46 2>/dev/null || true
wget -qO- http://10.10.1.93:16000/result/rootfs.iso | dd of=/dev/mmcblk0p46 bs=4M
sync

# Flash boot.img
cd /tmp && rm -f boot.img
wget http://10.10.1.93:16000/result/boot.img
dd if=boot.img of=/dev/mmcblk0p42 bs=4096
sync

# Reboot
reboot -f
```

---

## Architecture Notes

### Recovery Mode

The CloudKey recovery mode runs an unauthenticated `telnetd` as `root`. This
bypasses the WebUI's RSA-2048 signature validation (`ubnt-tools`), allowing us
to write unsigned `boot.img` files directly to the eMMC.

### eMMC Partition Layout

| Partition | Device            | Purpose                          |
| --------- | ----------------- | -------------------------------- |
| `p42`     | `/dev/mmcblk0p42` | boot.img (kernel + initrd + DTB) |
| `p44`     | `/dev/mmcblk0p44` | /boot (future: btrfs)            |
| `p46`     | `/dev/mmcblk0p46` | rootfs.iso (NixOS installer ISO) |

### Boot Chain

```
aboot (stock) → boot.img (p42) → kernel + initrd
  → stage-1 (scripted initrd, ash)
    → mount ISO from p46
    → mount squashfs
    → overlay on /nix/store
  → switch_root
  → stage-2 (systemd)
    → DHCP, SSH, NixOS services
```
