{
  config,
  lib,
  ...
}: {
  imports = [];

  boot = {
    supportedFilesystems = ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "zfs" "ntfs" "cifs" "nfs"];

    initrd = {
      availableKernelModules = ["nvme" "sd_mod" "thunderbolt" "usb_storage" "usbhid" "xhci_pci"];

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

    extraModulePackages = [];
  };

  fileSystems = {
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
    };

    "/boot" = {
      device = "zpool/boot";
      fsType = "zfs";
    };

    "/boot/efi" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0360721030005469-0:0-part1";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    "/boot/nixos" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0360721030005469-0:0-part2";
      fsType = "xfs";
    };

    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
    };

    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
    };

    "/var" = {
      device = "zpool/var";
      fsType = "zfs";
    };

    "/var/lib" = {
      device = "zpool/var/lib";
      fsType = "zfs";
    };

    "/var/lib/docker" = {
      device = "zpool/var/lib/docker";
      fsType = "zfs";
    };

    "/tmp" = {
      device = "zpool/tmp";
      fsType = "zfs";
    };
  };

  swapDevices = [];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableAllFirmware = true;

    enableRedistributableFirmware = true;
  };
}
