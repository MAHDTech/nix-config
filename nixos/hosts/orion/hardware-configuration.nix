{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
    ];

    # Use the latest kernel for newer ARM boards
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

    extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./packages/cix-npu-driver.nix { })
      (config.boot.kernelPackages.callPackage ./packages/cix-vpu-driver.nix { })
    ];

    initrd = {
      availableKernelModules = [
        "nvme"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "uas"
        "r8169" # Realtek network
        "r8152" # Realtek USB network
        "panthor" # Immortalis G720 GPU
        "panfrost"
      ];
      kernelModules = [
        "kvm"
        "aipu"
        "amvx"
      ];
    };

    kernelParams = [
      "console=ttyAMA0,115200n8"
      "console=tty0"
    ];

    # Modern boot management
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = lib.mkForce "/boot";
      };
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "update-orion-bios" ''
      set -euo pipefail

      # Safety check: Ensure we are running on the ORION host
      CURRENT_HOST=$(cat /etc/hostname 2>/dev/null || echo "UNKNOWN")
      if [ "$CURRENT_HOST" != "ORION" ] && [ "$CURRENT_HOST" != "orion-installer" ]; then
        echo "ERROR: This script is only intended to be run on the ORION host!"
        echo "Current host is: $CURRENT_HOST"
        exit 1
      fi

      # Safety check: Ensure architecture is aarch64
      if [ "$(uname -m)" != "aarch64" ]; then
        echo "ERROR: This script requires an aarch64 architecture!"
        exit 1
      fi

      # Safety check: Ensure network connectivity
      if ! ${pkgs.iputils}/bin/ping -c 1 -W 2 github.com >/dev/null 2>&1; then
        echo "ERROR: Cannot reach github.com. Please check your internet connection."
        exit 1
      fi

      BIOS_VERSION="1.1.0-1"

      echo "Downloading Radxa Orion O6 BIOS ''${BIOS_VERSION}..."
      TMPDIR=$(mktemp -d)
      cd $TMPDIR
      ${pkgs.curl}/bin/curl -sL "https://github.com/radxa-pkg/edk2-cix/releases/download/''${BIOS_VERSION}/edk2-cix_''${BIOS_VERSION}_all.deb" -o edk2.deb

      echo "Extracting..."
      ${pkgs.dpkg}/bin/dpkg-deb -x edk2.deb extracted

      echo "Cleaning up old EFI flasher files..."
      sudo rm -rf /boot/radxa-firmware

      echo "Installing EFI flasher to /boot/radxa-firmware..."
      sudo mkdir -p /boot/radxa-firmware
      sudo cp -r extracted/usr/share/edk2/radxa/orion-o6/* /boot/radxa-firmware/

      echo "Done!"
      echo ""
      echo "To flash the BIOS:"
      echo "1. Reboot the machine."
      echo "2. Press Esc or Del to enter the UEFI menu, or drop into the systemd-boot EFI shell."
      echo "3. Run the following commands:"
      echo "   fs0:"
      echo "   cd radxa-firmware"
      echo "   startup.nsh"

      rm -rf $TMPDIR
    '')
  ];

  hardware = {
    graphics.enable = true;
    enableRedistributableFirmware = true;
  };

  networking.useDHCP = lib.mkForce true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
