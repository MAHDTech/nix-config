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
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0360721030005469-0:0-part1";
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
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0360721030005469-0:0-part2";
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
  };

  swapDevices = [ ];

  networking = {
    useDHCP = lib.mkDefault false;
    interfaces = {
      enp13s0 = {
        name = "enp13s0";
        useDHCP = false;
        mtu = lib.mkForce 1500;
      };
      br0 = {
        name = "br0";
        useDHCP = true;
        mtu = 1500;
      };
    };
    bridges = {
      br0 = {
        interfaces = [ "enp13s0" ];
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableAllFirmware = true;

    enableRedistributableFirmware = true;
  };
}
