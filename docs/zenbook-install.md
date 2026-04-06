# ASUS Zenbook Snapdragon X Elite - NixOS Anywhere Guide

This guide describes how to install NixOS on the ASUS Zenbook A14 (UX3407R) using `nixos-anywhere`. You can choose between two methods for the target environment:

- **Option A**: Using an Ubuntu Live USB (Legacy method).
- **Option B**: Using the Custom NixOS ISO (Recommended).

## ⚠️ CRITICAL: The "No-Kexec" Method

The Snapdragon X Elite requires a highly specific kernel. Standard `nixos-anywhere` attempts to `kexec` into a generic installer kernel, which **will crash** (black screen). To avoid this, we skip the `kexec` phase and run the installer directly within the live environment.

## Option A: Using Ubuntu Live (Legacy)

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

## Option B: Using the Custom NixOS ISO (Recommended)

This method is faster and more reliable. The custom ISO contains the exact kernel and firmware needed for the Snapdragon X Elite, ensuring that components like the internal NVMe drive are visible immediately.

> **Why this is better**: Standard Ubuntu kernels lack the `qcom_geni_se` and `nvme` configuration necessary to see the internal storage on Snapdragon X Elite hardware. Our custom ISO includes these modules in the initrd, guaranteeing that `nixos-anywhere` can find the disk.

### 1. Build the ISO

On your **source machine** (must have Nix installed), build the ISO:

```bash
nix build .#zenbook-iso
```

### 2. Prepare the USB

Flash the ISO to a USB stick (replace `/dev/sdX` with your USB device):

```bash
sudo dd if=result/iso/nixos.iso of=/dev/sdX bs=4M status=progress && sync
```

### 3. Boot the Zenbook

1.  Insert the USB into the Zenbook.
2.  Boot into BIOS (Press **F2** repeatedly after power-on).
3.  **Disable Secure Boot** (Security tab).
4.  Save and Exit.
5.  Press **F7** repeatedly during boot to select the USB drive.

### 4. Connect and Prepare

Once booted into the NixOS installer:

1.  **Network**: Connect via WiFi (use `nmtui`) or USB Ethernet.
2.  **SSH**: The ISO automatically enables SSH with the root password set to `nixos`.
3.  **Note Target IP**: Run `ip addr` to find the IP address of the Zenbook.

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
