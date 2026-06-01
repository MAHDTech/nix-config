# NixOS Installation Guide

End-to-end instructions for building a NixOS installer image, flashing it to USB, and
installing via `nixos-anywhere`.

All commands are copy-paste-ready once you set the
variables at the top of each section.

---

## Available Installers

The following installer images are defined in this flake, one per host:

| Flake target        | Host    | Architecture  |
| ------------------- | ------- | ------------- |
| `installer-jons`    | JONS    | x86_64-linux  |
| `installer-arc`     | ARC     | x86_64-linux  |
| `installer-zenbook` | ZENBOOK | aarch64-linux |
| `installer-orion`   | ORION   | aarch64-linux |

Each installer image includes:

- The host's hardware-specific kernel and firmware
- SSH enabled with password authentication (`root` / `nixos`, password `nixos`)
- `nixos` user also set to password `nixos` for SSH access
- Tools: `git`, `vim`, `curl`, `parted`, `htop`, `pciutils`, `usbutils`

**NOTE:** To show all available flake targets, run `nix flake show --impure --all-systems`.

---

## Step 1 — Set Variables

Set these once. Every command below uses them verbatim.

```bash
# The flake target to build and install (see table above)
INSTALLER_NAME="installer-zenbook"

# The NixOS host configuration to install (uppercase, matches flake)
HOST_NAME="ZENBOOK"

# USB drive to flash the installer image to (check with: lsblk)
USB_DRIVE="/dev/sdX"

# IP address of the target machine once booted into the installer
TARGET_IP="10.10.1.126"

# Your local SSH private key (used to bypass 1Password agent)
SSH_KEY="$HOME/.ssh/id_ed25519"
```

---

## Step 2 — List and Build the Installer Image

### List all available installers

```bash
nix flake show --impure --all-systems 2>/dev/null | grep installer
```

### Build the installer image

```bash
nix build .#${INSTALLER_NAME} --print-build-logs --impure
```

> The output is a raw EFI disk image at `./result/` (a `.raw` file).
> Build time varies — hosts with a custom kernel (e.g. ZENBOOK) take 30–60 minutes on first build; subsequent builds are fast due to caching.

---

## Step 3 — Flash to USB

> [!CAUTION]
> Double-check `USB_DRIVE` before running. `dd` will **permanently erase** the target device.

```bash
# Verify you have the right device before flashing
lsblk ${USB_DRIVE}

# Flash the image
sudo dd if=$(ls result/*.raw) of=${USB_DRIVE} bs=4M status=progress conv=fdatasync

# Verify the GPT and EFI partition are present
sudo fdisk -l ${USB_DRIVE}

# Fix GPT backup header if needed (safe to run always)
sudo sgdisk -e ${USB_DRIVE}
```

Expected output from `fdisk`: a GPT with an **EFI System** partition and a Linux root partition.

> [!NOTE]
> The image is a raw GPT disk image (not an ISO). ARM64 UEFI has no BIOS/CSM fallback
> and requires a proper EFI System Partition with `BOOTAA64.EFI`.
> x86_64 images use `BOOT-X64.EFI` (note: filename only, not a config symbol).

---

## Step 4 — Boot the Installer

1. Insert the USB drive into the target machine.
2. Power on and enter firmware (usually **F2**, **F12**, **DEL**, or **ESC** during POST).
3. **Disable Secure Boot** if present (Security tab in firmware settings).
4. Select the USB drive from the boot menu.

> [!TIP]
> On ASUS Zenbook: press **ESC** repeatedly after power-on → "Enter Setup" →
> Security tab → disable Secure Boot → save → ESC again → select USB from boot menu.

The machine will boot into the NixOS installer with the hostname `installer-<host>`.

---

## Step 5 — Get the IP Address

Once booted, the machine should obtain a DHCP address automatically. Find it:

**On the target machine** (if you have a keyboard/display):

```bash
ip addr show
```

**From your router** or a network scan:

```bash
# Install nmap if needed, then scan the local subnet
nmap -sn 10.10.1.0/24
```

Then set your variable:

```bash
TARGET_IP="<address shown above>"
```

---

## Step 6 — Verify SSH Access

Confirm you can reach the installer before running `nixos-anywhere`:

```bash
# As root (password: nixos)
ssh root@${TARGET_IP}

# Or as nixos user (password: nixos)
ssh nixos@${TARGET_IP}
```

Both accounts use password `nixos`. SSH password authentication is enabled in all installers.

---

## Step 7 — Install with nixos-anywhere

Run from your **source machine** in the root of this repository.

### Standard install (no 1Password)

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#${HOST_NAME} \
  --target-host root@${TARGET_IP} \
  --build-on remote \
  --phases disko,install
```

### With 1Password SSH agent bypass

If you use 1Password as your SSH agent, it aggressively offers all keys in your vault.
SSH drops the connection after 6 failed attempts (`MaxAuthTries`) before
`nixos-anywhere` can authenticate. Bypass it with:

```bash
env SSH_AUTH_SOCK="" nix run github:nix-community/nixos-anywhere -- \
  --flake .#${HOST_NAME} \
  --target-host root@${TARGET_IP} \
  --build-on remote \
  --phases disko,install \
  -i ${SSH_KEY} \
  --ssh-option "IdentitiesOnly=yes" \
  --ssh-option "IdentityAgent=none"
```

> [!IMPORTANT]
> `--phases disko,install` is **mandatory** for ARM64 hosts (ZENBOOK, ORION).
> It skips the `kexec` phase which causes a black screen on Snapdragon hardware.
> It also skips the automatic reboot so you can inspect the result first.

### Flag reference

| Flag                                | Purpose                                                         |
| ----------------------------------- | --------------------------------------------------------------- |
| `--flake .#${HOST_NAME}`            | The NixOS configuration to install                              |
| `--target-host root@${TARGET_IP}`   | SSH target on the installer                                     |
| `--build-on remote`                 | Build the closure on the target's CPU (required for cross-arch) |
| `--phases disko,install`            | Skip kexec + auto-reboot (required for ARM64)                   |
| `env SSH_AUTH_SOCK=""`              | Hide 1Password agent socket from the shell                      |
| `-i ${SSH_KEY}`                     | Explicit private key, bypasses agent                            |
| `--ssh-option "IdentitiesOnly=yes"` | Only use the key provided with `-i`                             |
| `--ssh-option "IdentityAgent=none"` | Ignore `IdentityAgent` in `~/.ssh/config`                       |

---

## Step 8 — Post-Installation

Once `nixos-anywhere` finishes:

```bash
# On the target machine — reboot into the new system
ssh root@${TARGET_IP} reboot
```

Remove the USB drive when the machine powers off. On next boot, select the new
**NixOS** entry from the boot menu (or it may boot automatically).

---

## Troubleshooting

| Symptom                            | Cause                                      | Fix                                                                              |
| ---------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------- |
| USB not found in boot menu         | Image wasn't written as a raw GPT disk     | Re-flash with `dd`, verify with `fdisk -l`                                       |
| Black screen during install        | `kexec` failed on ARM64                    | Add `--phases disko,install`                                                     |
| `Too many authentication failures` | 1Password SSH agent offering too many keys | Use `env SSH_AUTH_SOCK=""` and `-i` flag variant above                           |
| NVMe not found during install      | Missing initrd modules in hardware config  | Check `hardware-configuration.nix` for `nvme` in `initrd.availableKernelModules` |
| WiFi not available in installer    | May need USB Ethernet adapter as fallback  | Configure WiFi via `iwctl` (iwd): `iwctl station wlan0 connect <SSID>`           |
| `disko` fails with device busy     | Previous partition table still mounted     | Run `umount -R /mnt` and retry                                                   |
