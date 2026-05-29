# ASUS Zenbook Snapdragon X Elite

How to install NixOS on the ASUS Zenbook A14 (UX3407R) using `nixos-anywhere` and a custom NixOS disk image with the necessary Qualcomm patches.

The custom image contains the exact kernel and firmware needed for the Snapdragon X Elite, ensuring that components like the internal NVMe drive are visible immediately.

## 1. Build the Image

On your **source machine** (must have Nix installed), build the raw EFI disk image:

```bash
nix build .#installer-zenbook --impure --print-build-logs
```

### 2. Prepare the USB

The build outputs a raw disk image with a proper GPT and EFI System Partition.

Flash it to your USB stick (replace `/dev/sdb` with your USB device):

```bash
USB_DRIVE=/dev/sdb

sudo dd if=$(ls result/*.raw) of=${USB_DRIVE} bs=4M status=progress conv=fdatasync
```

Verify the USB has a GPT with an ESP:

```bash
sudo fdisk -l ${USB_DRIVE}
# Should show a GPT with an EFI System partition and a Linux root partition

# Fix the GPT if needed with
sudo sgdisk -e ${USB_DRIVE}
```

### 3. Boot the Zenbook

1. Insert the USB into the Zenbook and power on.
2. Press **ESC** repeatedly after power-on and select "Enter Setup".
3. **Disable Secure Boot** (Security tab).
4. Save and Exit.
5. Press **ESC** repeatedly after power-on and select the USB drive.

### 4. Connect and Prepare

Once booted into the NixOS installer:

1. **Network**: Connect via WiFi (use `nmtui`) or USB Ethernet.
2. **SSH**: The image automatically enables SSH with the root password set to `nixos`.
3. **Note Target IP**: Run `ip addr` to find the IP address of the Zenbook.

## 2. Installation

Run the following command from your **source machine** (or from the Zenbook itself if you cloned the repo there).

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#ZENBOOK \
  --target-host root@<TARGET_IP> \
  --build-on remote \
  --phases disko,install
```

### Key Flags

- `--phases disko,install`: **MANDATORY.** Skips the `kexec` phase which
  causes the black screen on Snapdragon hardware. It also skips the automatic
  reboot, allowing you to inspect the installation.
- `--build-on remote`: Builds the system using the Zenbook's ARM64 CPU.

## 3. Post-Installation

Once the script finishes:

1. **Manual Reboot**: Run `reboot` on the Zenbook.
2. **Select NixOS**: Select the new NixOS entry from the boot menu.
3. **Success**: The system will boot using the custom kernel with all Snapdragon patches applied.

### Troubleshooting

- **USB Won't Boot / Not Found in Boot Menu**: The image must be a raw EFI disk
  image (GPT + ESP), not an ISO. ARM64 UEFI firmware has no BIOS/CSM fallback
  and requires a proper EFI System Partition with `BOOTAA64.EFI`. Verify with
  `fdisk -l /dev/sdX`.
- **Black Screen during Install**: Ensure you included `--phases disko,install`
  to skip the kexec step.
- **NVMe Not Found**: Check `hardware-configuration.nix` to ensure the `nvme`
  and `qcom_geni_se` modules are in `initrd.availableKernelModules`.
