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
        "mpt3sas"
        "nvme"
        "sd_mod"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];

      kernelModules = [
        "dm-snapshot"
        "zfs"
      ];

    };

    kernelModules = [
      "kvm-amd"
    ];

    kernelParams = [
      "mitigations=off"
      "threadirqs"
    ];

    extraModulePackages = [ ];

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
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_0347023040002297-0:0-part1";
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

    # Legacy mount point for tmp using ZFS
    "/tmp" = {
      device = "zpool/tmp";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableAllFirmware = true;

    enableRedistributableFirmware = true;
  };
}
