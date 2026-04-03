{
  config,
  lib,
  ...
}:
{
  imports = [ ];

  boot = {
    supportedFilesystems = [
      "btrfs"
      "cifs"
      "exfat"
      "f2fs"
      "nfs"
      "ntfs"
      "vfat"
      "xfs"
      "zfs"
    ];

    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "xhci_pci"

        # Intel VMD
        "vmd"
      ];

      kernelModules = [
        "dm-snapshot"
        "zfs"
      ];
    };

    kernelModules = [
      "kvm-intel"

      # Intel VMD
      "vmd"
    ];

    kernelParams = [
      "mitigations=off"
      "threadirqs"

      # Intel VMD
      "nvme_load=YES"

      # Disable USB autosuspend
      "btusb.enable_autosuspend=n"

      # Disable Intel CNVi device power management
      "intel_idle.max_cstate=0"
      "pcie_aspm=off"

      # Laptop screen
      "acpi_osi=Linux"
      "acpi_backlight=native"
    ];

    blacklistedKernelModules = [ ];

    extraModulePackages = [ ];

    extraModprobeConfig = ''
      # Keep Bluetooth coexistence disabled for better BT audio stability
      options iwlwifi bt_coex_active=0

      # Enable software crypto (helps BT coexistence)
      options iwlwifi swcrypto=1

      # Disable power saving on Wi-Fi module to reduce radio state changes that might disrupt BT
      options iwlwifi power_save=0

      # Disable Unscheduled Automatic Power Save Delivery (U-APSD) to improve BT audio stability
      options iwlwifi uapsd_disable=1

      # Disable D0i3 power state to avoid problematic power transitions
      options iwlwifi d0i3_disable=1

      # Set power scheme for performance (iwlmvm)
      options iwlmvm power_scheme=1
    '';
  };

  # Legacy mount points
  fileSystems = {

    # Legacy mount point for root using ZFS
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    # Legacy mount point for boot using ZFS
    "/boot" = {
      device = "zpool/boot";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    # UEFI boot partition on USB
    "/boot/efi" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0364621040007011-0:0-part1";
      fsType = "vfat";
      options = [
        "umask=0022"
        "dmask=0022"
        "fmask=0022"
        "noatime"
        "nofail"
      ];
      neededForBoot = true;
    };

    # NixOS configuration on USB
    "/boot/nixos" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0364621040007011-0:0-part2";
      fsType = "xfs";
      neededForBoot = false;
    };

    # Legacy mount point for home using ZFS
    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # Legacy mount point for nix using ZFS
    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    # Legacy mount point for var using ZFS
    "/var" = {
      device = "zpool/var";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    # Legacy mount point for var/lib using ZFS
    "/var/lib" = {
      device = "zpool/var/lib";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    # Legacy mount point for var/lib/docker using ZFS
    "/var/lib/docker" = {
      device = "zpool/var/lib/docker";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # Legacy mount point for var/lib/containers using ZFS
    "/var/lib/containers" = {
      device = "zpool/var/lib/containers";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # Legacy mount point for tmp using ZFS
    "/tmp" = {
      device = "zpool/tmp";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # Legacy mount point for persistent using ZFS
    #"/persistent" = {
    #  device = "zpool/persistent";
    #  fsType = "zfs";
    #  options = [
    #    "zfsutil"
    #  ];
    #  neededForBoot = true;
    #};
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableAllFirmware = true;

    enableRedistributableFirmware = true;
  };
}
