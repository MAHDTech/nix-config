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

1. Power off the CloudKey.
2. Hold the reset button with a paperclip.
3. Power it on while holding reset.
4. Hold until the LED flashes white/blue (~10 seconds).
5. Release — the CloudKey boots into recovery at `10.10.200.200`.

### 4. Flash with the automated script

Make sure to include `inetutils` in the `nix-shell` so that `telnet` is available:

```bash
nix-shell -p expect inetutils --run "./nixos/hosts/bootycall/scripts/flash-recovery.exp 10.10.200.200 10.10.1.93 16000"
```

The script will:

- Connect to the CloudKey via `telnet`.
- Save a complete log of the console session to `flash-recovery.log`.
- Track and output the exact timestamp and duration of each step.
- Flash `rootfs.iso` → `/dev/mmcblk0p46` (userdata partition) using a named pipe (FIFO) to stream the download and verify the exact byte size on the fly (with a 30s network timeout buffer).
- Flash `boot.img` → `/dev/mmcblk0p42` (boot partition) and verify its written size.
- Sync and reboot.

### 5. Wait for NixOS to boot

After reboot, wait 5–7 minutes for the full boot sequence (booting can be slow due to the CPU running at its bootloader-default frequency and decompressing SquashFS on the fly):

- **Stage-1 (scripted initrd)**: mounts ISO, squashfs, overlay.
- **Stage-2 (systemd)**: starts services, DHCP, SSH.

Check your router's DHCP lease table for MAC `74:83:c2:7b:82:9f`.

---

## Capturing & Parsing Ramoops Dumps

If the system fails to boot (no DHCP after 5–7 minutes), capture a ramoops dump to inspect the kernel ring buffer logs.

### 1. Start netcat listener

On your host machine, listen on port `16000` to receive the dump. Depending on your version of `nc`, run one of the following:

```bash
# BSD netcat (standard on NixOS)
nc -l 16000 > /tmp/ramoops_dump_latest.bin

# Traditional netcat
nc -l -p 16000 > /tmp/ramoops_dump_latest.bin
```

### 2. Run the capture script

In another terminal, run:

```bash
#nix-shell -p expect --run "./nixos/hosts/bootycall/scripts/capture-dump.exp <cloud-key-ip> <host-ip> <host-port>"
nix-shell -p expect --run "./nixos/hosts/bootycall/scripts/capture-dump.exp 10.10.200.200 10.10.1.93 16000"
```

### 3. Parse and analyze the dump

Use the Python parser to decode the persistent RAM zone (`DBGC` signature) and extract/decompress the logs:

```bash
python3 nixos/hosts/bootycall/scripts/parse_ramoops.py
```

This decompresses and extracts the logs into `/tmp/parsed_ramoops_latest/`. You can view the full console log output there:

```bash
cat /tmp/parsed_ramoops_latest/chunk_14_console.txt
```

---

## Manual Flashing (without expect)

If you need to flash manually, run the commands sequentially via telnet. Be sure to specify the
`-T 30` option in `wget` so that the download will timeout after 30 seconds rather than hanging if
the connection drops:

```bash
telnet 10.10.200.200
# Login: root / ubnt

# Flash rootfs.iso
umount /dev/mmcblk0p46 2>/dev/null || true
wget -T 30 -qO- http://10.10.1.93:16000/result/rootfs.iso | dd of=/dev/mmcblk0p46 bs=4M
sync

# Flash boot.img
cd /tmp && rm -f boot.img
wget -T 30 http://10.10.1.93:16000/result/boot.img
dd if=boot.img of=/dev/mmcblk0p42 bs=4096
sync

# Reboot
reboot -f
```

---

## Architecture Notes

### Recovery Mode

The CloudKey recovery mode runs an unauthenticated `telnetd` as `root`. This bypasses the WebUI's
RSA-2048 signature validation (`ubnt-tools`), allowing us to write unsigned `boot.img` files
directly to the eMMC.

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
