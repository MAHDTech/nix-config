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
      "kvm-amd"
    ];

    kernelParams = [
      "mitigations=off"
      "threadirqs"
    ];

    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
     };

    "/boot" = {
      device = "bpool/boot";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
     };

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

    "/boot/nixos" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0360721030005469-0:0-part2";
      fsType = "xfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    "/var" = {
      device = "zpool/var";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    "/var/lib" = {
      device = "zpool/var/lib";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    "/var/lib/docker" = {
      device = "zpool/var/lib/docker";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

    "/var/lib/containers" = {
      device = "zpool/var/lib/containers";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = true;
    };

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
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableAllFirmware = true;

    enableRedistributableFirmware = true;
  };
}
