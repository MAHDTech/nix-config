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
      "reiserfs"
      "vfat"
      "f2fs"
      "xfs"
      "zfs"
      "ntfs"
      "cifs"
      "nfs"
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
      ];

      kernelModules = [
        "zfs"
      ];
    };

    kernelModules = [
      "kvm-intel"
    ];

    kernelParams = [
      "mitigations=off"
      "threadirqs"
      "zfs_force=1"
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
      device = "bpool/boot";
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
      neededForBoot = true;
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
      neededForBoot = true;
    };

    # Legacy mount point for var/lib/containers using ZFS
    "/var/lib/containers" = {
      device = "zpool/var/lib/containers";
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
      neededForBoot = true;
    };
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableAllFirmware = true;

    enableRedistributableFirmware = true;
  };
}
