# NixOS Bootstrapping & Secret Setup Guide

A guide to;

- build a NixOS installer
- flash it to USB
- Provision a new host using `nixos-anywhere`
- Setting up **OpNix** with a **1Password Service Account** token.

---

## 1. Set Configuration Variables

Set these environment variables in your terminal before running any subsequent commands.

```bash
# Name of the host configuration (uppercase, matches flake target)
NIXOS_HOSTNAME="ZENBOOK"

# Name of the installer configuration (from the list below)
INSTALLER_NAME="installer-zenbook"

# USB device path to write the installer to (verify via: lsblk)
USB_DRIVE="/dev/sdX"

# Target IP address of the booted installer machine
NIXOS_TARGET_IP="10.10.1.126"

# Path to your local SSH private key
NIXOS_SSH_KEY="$HOME/.ssh/id_ed25519"

# Your 1Password Service Account Token for this host (generated in Section 5)
OPNIX_TOKEN="ov_token_..."
```

---

## 2. Available Installers

The installer images defined in this flake include host-specific kernels, utility tools, and SSH enabled with password authentication (`root`/`nixos`, password: `nixos`).

| Flake target        | Host    | Architecture    |
| :------------------ | :------ | :-------------- |
| `installer-jons`    | JONS    | `x86_64-linux`  |
| `installer-arc`     | ARC     | `x86_64-linux`  |
| `installer-zenbook` | ZENBOOK | `aarch64-linux` |
| `installer-orion`   | ORION   | `aarch64-linux` |

> [!TIP]
> To list all available installer targets in the repository, run:
>
> ```bash
> nix flake show --impure --all-systems 2>/dev/null | grep installer
> ```

---

## 3. Build the Installer Image

Run the build command from the root of this repository on your deployment machine:

```bash
nix build .#${INSTALLER_NAME} --print-build-logs --impure
```

The output will be a raw EFI disk image (`.raw` file) located under the `./result/` directory.

---

## 4. Flash to USB

> [!CAUTION]
> Double-check the target `USB_DRIVE` device name before flashing. Writing to the wrong device will **permanently erase** its contents.

```bash
# Verify the drive is correct
lsblk ${USB_DRIVE}

# Flash the raw image to the USB drive
sudo dd if=$(ls result/*.raw) of=${USB_DRIVE} bs=4M status=progress conv=fdatasync

# Ensure the GPT layout is healthy
sudo sgdisk -e ${USB_DRIVE}
```

---

## 5. Boot Target & Verify SSH

1. Insert the USB drive into the target host.
2. Boot into the firmware menu (commonly **F2**, **F12**, or **ESC**) and **disable Secure Boot**.
3. Select the USB drive to boot.
4. Once booted, retrieve the target IP:
   - **Directly**: Run `ip addr show` on the target machine.
   - **Indirectly**: Scan the local network using `nmap -sn 10.10.1.0/24`.
5. Verify SSH connectivity from your deployment machine (default password is `nixos`):
   ```bash
   ssh root@${NIXOS_TARGET_IP}
   ```

---

## 6. Setup OpNix 1Password Token

OpNix decrypts and mounts host secrets at runtime via a 1Password Service Account.

### Generate the Service Account Token

Make sure you are logged in to the `op` CLI locally, and then run:

```bash
op service-account create "$NIXOS_HOSTNAME" --vault "fleet:read_items"
```

> [!IMPORTANT]
> The 1Password CLI displays the generated token **only once**. Copy it immediately and assign it to your `OPNIX_TOKEN` environment variable in your deployment shell.

---

## 7. Run nixos-anywhere with Secrets Injection

Because Nix builds are pure and offline, the 1Password token cannot be fetched during build time.

Instead, we stage the token inside a temporary directory structure and inject it using `nixos-anywhere`'s `--extra-files` mechanism.

### Prepare the Secret Token Locally

- If you want to use the token with `nixos-anywhere`,

```bash
# Create a secure temporary directory mirroring the target root directory
OPNIX_TEMP=$(mktemp -d)

# Write the token to the etc directory inside the temp path
mkdir -p "$OPNIX_TEMP/etc"
echo "$OPNIX_TOKEN" > "$OPNIX_TEMP/etc/opnix-token"
chmod 400 "$OPNIX_TEMP/etc/opnix-token"
```

- If you want to set the token post-install;

```bash
# Run this inside the host after installation.
opnix token set
```

### Option A: Standard Deployment

Run the standard deployment:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$OPNIX_TEMP" \
  --flake .#${NIXOS_HOSTNAME^^} \
  --target-host root@${NIXOS_TARGET_IP} \
  --build-on remote \
  --phases disko,install
```

### Option B: Deploy with 1Password SSH Agent Bypass

Use this variation if your local SSH setup attempts all keys in your 1Password agent vault, causing `Too many authentication failures` errors:

```bash
env SSH_AUTH_SOCK="" nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$OPNIX_TEMP" \
  --flake .#${NIXOS_HOSTNAME^^} \
  --target-host root@${NIXOS_TARGET_IP} \
  --build-on remote \
  --phases disko,install \
  -i ${NIXOS_SSH_KEY} \
  --ssh-option "IdentitiesOnly=yes" \
  --ssh-option "IdentityAgent=none"
```

> [!IMPORTANT]
> `--phases disko,install` is mandatory for ARM64 targets (such as `ZENBOOK` and `ORION`) to avoid crashes during the `kexec` phase and prevent automatic reboot.

### Clean up Local Secrets Staging

Once the deployment script finishes, clean up the temporary directory:

```bash
rm -rf "$OPNIX_TEMP"
```

---

## 8. Post-Installation

Once the deployment completes:

1. Reboot the target host:

```bash
ssh root@${NIXOS_TARGET_IP} reboot
```

2. Unplug the USB drive when the host shuts down.

3. Upon first boot of the new system, verify that the OpNix daemon is active and running:

```bash
systemctl status onepassword-secrets.service
```
