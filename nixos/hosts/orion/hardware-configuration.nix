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
        "r8169" # Realtek RTL8126 5GbE (mainline r8169 supports PCI ID 10ec:8126)
        "r8152" # Realtek USB Ethernet (fallback for USB dongles)
        "dwc3" # DWC3 USB3 controller
      ];
      kernelModules = [ ];
    };

    # Load after boot (not needed during initrd)
    kernelModules = [
      "kvm"
      "panthor" # Immortalis-G720 MC10 GPU (CSF-based)
      "aipu" # CIX NPU
      "amvx" # CIX VPU
    ];

    # Prevent panfrost from auto-loading (wrong driver for G720, use panthor)
    blacklistedKernelModules = [ "panfrost" ];

    kernelParams = [
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "nowatchdog" # Disable hardware watchdog
      "module_blacklist=sbsa_gwdt" # Disable sbsa_gwdt module (watchdog reboot loops)
    ];

    # 5GbE and network performance tuning
    kernel.sysctl = {
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.core.rmem_default" = 1048576;
      "net.core.wmem_default" = 1048576;
      "net.ipv4.tcp_rmem" = "4096 1048576 16777216";
      "net.ipv4.tcp_wmem" = "4096 1048576 16777216";
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    # Modern boot management
    loader = {
      systemd-boot = {
        enable = true;

        extraFiles = {
          "efi/shell.efi" = "${pkgs.edk2-uefi-shell}/shell.efi";
        };

        extraEntries = {
          "update-bios.conf" = ''
            title Update Radxa BIOS
            efi /efi/shell.efi
            options -delay 0 \radxa-firmware\update-bios.nsh
            sort-key z_update_bios
          '';
        };
      };

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

      BIOS_VERSION="1.2.1"

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

      echo "Generating interactive EFI update wrapper..."
      cat << 'EOF' | sudo tee /boot/radxa-firmware/update-bios.nsh >/dev/null
      @echo -off
      echo .
      echo =================================================
      echo "  Radxa Orion O6 BIOS Update"
      echo =================================================
      echo .
      echo WARNING: DO NOT TURN OFF POWER DURING THE UPDATE
      echo Press 'q' to abort, or any other key to proceed.
      echo .
      pause -q
      if %lasterror% neq 0 then
      goto do_abort
      endif

      if exist fs0:\radxa-firmware\startup.nsh then
      fs0:
      endif
      if exist fs1:\radxa-firmware\startup.nsh then
      fs1:
      endif
      if exist fs2:\radxa-firmware\startup.nsh then
      fs2:
      endif

      cd radxa-firmware
      startup.nsh
      goto done

      :do_abort
      echo "Update aborted by user."

      :done
      EOF
      echo "Done!"
      echo ""
      echo "To flash the BIOS:"
      echo "1. Reboot the machine."
      echo "2. Select 'Update Radxa BIOS' from the systemd-boot menu."
      echo "   (If it does not automatically launch, select the EFI Shell and run:"
      echo "    fs0: -> cd radxa-firmware -> update-bios.nsh)"

      rm -rf $TMPDIR
    '')
  ];

  hardware = {
    enableRedistributableFirmware = true;
  };

  # Use systemd-networkd for Ethernet management
  networking.useNetworkd = true;
  networking.useDHCP = lib.mkForce false;

  systemd.network.networks."10-lan" = {
    matchConfig.Name = [
      "en*"
      "eth*"
    ];
    networkConfig.DHCP = "yes";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
