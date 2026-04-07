# ASUS Zenbook Snapdragon X Elite

How to install NixOS on the ASUS Zenbook A14 (UX3407R) using `nixos-anywhere` and a custom NixOS ISO with the necessary Qualcomm patches.

The custom ISO contains the exact kernel and firmware needed for the Snapdragon X Elite, ensuring that components like the internal NVMe drive are visible immediately.

### 1. Build the ISO

On your **source machine** (must have Nix installed), build the ISO:

```bash
nix build .#zenbook-sd-image
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
