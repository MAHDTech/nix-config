# ASUS Zenbook Snapdragon X Elite - NixOS Anywhere Guide

This guide describes how to install NixOS on the ASUS Zenbook A14 (UX3407R) using `nixos-anywhere` from an Ubuntu Live USB environment.

## ⚠️ CRITICAL: The "No-Kexec" Method

The Snapdragon X Elite requires a highly specific kernel. Standard `nixos-anywhere` attempts to `kexec` into a generic installer kernel, which **will crash** (black screen). To avoid this, we install Nix directly into the Ubuntu Live session and run the installer from there, skipping the kexec phase entirely.

## 1. Prerequisites

### Target Machine (Zenbook)

1.  **Boot Ubuntu Live**: Create an Ubuntu 24.04 (or later) aarch64 Live USB and boot the Zenbook.
2.  **Network Connectivity**:
    - Connect to WiFi or use **USB Tethering** from an Android phone.
3.  **Install Nix on Ubuntu**:

    ```bash
    # Install Nix (multi-user mode)
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

    # Enable Flakes
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    ```

4.  **Enable SSH & Root Access**:

    ```bash
    sudo apt update && sudo apt install -y openssh-server
    sudo passwd ubuntu # Set a temporary password
    sudo passwd root   # Set a root password (required for nixos-anywhere)

    # Allow root login over SSH for the duration of the install
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    ```

## 2. Installation

Run the following command from your **source machine** (or from the Zenbook itself if you cloned the repo there).

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#ZENBOOK \
  --target-host root@<TARGET_IP> \
  --build-on remote \
  --phases disko,install
```

### Key Flags:

- `--phases disko,install`: **MANDATORY.** Skips the `kexec` phase which causes the black screen on Snapdragon hardware. It also skips the automatic reboot, allowing you to inspect the installation.
- `--build-on remote`: Builds the system using the Zenbook's ARM64 CPU.

## 3. Post-Installation

Once the script finishes:

1.  **Manual Reboot**: Run `reboot` on the Zenbook.
2.  **Select NixOS**: Select the new NixOS entry from the boot menu.
3.  **Success**: The system will boot using the custom kernel with all Snapdragon patches applied.

### Troubleshooting

- **Black Screen during Install**: Ensure you included `--phases disko,install` to skip the kexec step.
- **NVMe Not Found**: Check `hardware-configuration.nix` to ensure the `nvme` and `qcom_geni_se` modules are in `initrd.availableKernelModules`.
