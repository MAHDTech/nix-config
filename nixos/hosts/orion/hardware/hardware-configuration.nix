{
  config,
  lib,
  pkgs,
  ...
}:
let
  cix-noe-umd = pkgs.callPackage ../packages/cix-noe-umd.nix { };
  cix-dsp-firmware = pkgs.callPackage ../packages/cix-dsp-firmware.nix { };
  sky1-firmware = pkgs.callPackage ../packages/sky1-firmware.nix { };
  # EDK2 BIOS version for the BIOS update script
  # TODO: Update when Radxa ships EDK2 with the IORT SMMU fix
  orionBiosVersion = "1.2.1";
in
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
    ];

    # Custom patched mainline v7.0 kernel is configured dynamically
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ../kernel.nix { };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../packages/cix-npu-driver.nix { })
      (config.boot.kernelPackages.callPackage ../packages/cix-vpu-driver.nix { })
    ];

    initrd = {
      availableKernelModules = [
        "nvme"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "xhci_hcd"
        "xhci_plat_hcd"
        "uas"
        "r8169" # Realtek RTL8126 5GbE (mainline r8169 supports PCI ID 10ec:8126)
        "r8152" # Realtek USB Ethernet (fallback for USB dongles)
        "thunderbolt"
        "ax88179_178a" # ASIX AX88179 USB Ethernet
        "cdc_ncm" # CDC NCM USB Ethernet
        "cdc_ether" # CDC Ether USB Ethernet
        "usbnet" # USB network core
        # Cadence cdns3 USB controller (PCIe-attached on CIX P1)
        # Live device shows cdns3_pci_wrap / cdnsp_udc_pci loading, not generic dwc3
        "cdns3"
        "cdns3_pci_wrap"
      ];
      kernelModules = [ ];
    };

    # Load after boot (not needed during initrd)
    kernelModules = [
      "kvm"
      "panthor" # Immortalis-G720 MC10 GPU (CSF-based)
      "aipu" # CIX NPU
      "amvx" # CIX VPU
      # Vendor Cadence USB SSP host/device glue drivers
      # Loaded in stage 2 to enable USB clocks (sky1_usb_clk_enable_all) safely
      "cdnsp"
      "cdnsp-sky1"
      # USB-C Power Delivery and DisplayPort Alt Mode
      # Orion O6 has 2x USB-C ports; one supports DP Alt Mode
      # These modules exist in defconfig as =m but are never auto-loaded
      "typec"
      "typec_ucsi"
      "ucsi_acpi"
      "typec_displayport"
      # ACPI CPPC cpufreq — confirmed auto-loading on live device, explicit for clarity
      "acpi_cppc_cpufreq"
    ];

    # Prevent panfrost from loading (wrong driver for Immortalis-G720 CSF, use panthor)
    # Belt-and-suspenders: NixOS blacklistedKernelModules option not working on live device;
    # also add via module_blacklist= kernel param below
    blacklistedKernelModules = [ "panfrost" ];

    kernelParams = [
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "nowatchdog" # Suppress all platform watchdogs at boot (works on built-in drivers too)
      # Belt-and-suspenders panfrost blacklist via kernel param (NixOS option alone not sufficient)
      "module_blacklist=panfrost"
      # clk_ignore_unused: prevent kernel from disabling clocks before drivers initialise
      # Required on CIX P1 to avoid slow boot and hardware init races
      "clk_ignore_unused"
      # NOTE: module_blacklist=sbsa_gwdt removed — sbsa_gwdt is built-in (not a module)
      # so blacklisting it has no effect. nowatchdog handles watchdog suppression instead.
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
    cix-noe-umd
    pkgs.tpm2-tools # TPM 2.0 userspace tools (future use — tpm2_getrandom, tpm2_getcap, etc.)
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

      BIOS_VERSION="${orionBiosVersion}"

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
    firmware = [
      sky1-firmware
      cix-dsp-firmware
    ];
  };

  services.udev.extraRules = ''
    KERNEL=="aipu", MODE="0660", GROUP="render"
  '';

  # AIPULIB_PATH: scoped to interactive sessions only
  # NPU applications are launched via nix-shell; global LD_LIBRARY_PATH breaks system tools
  environment.sessionVariables = {
    AIPULIB_PATH = "${cix-noe-umd}/lib";
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
