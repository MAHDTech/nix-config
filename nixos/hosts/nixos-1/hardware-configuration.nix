{ lib, ... }:
{
  imports = [ ];

  boot = {
    supportedFilesystems = [
      "vfat"
      "xfs"
      "zfs"
      "cifs"
      "nfs"
    ];

    initrd = {
      availableKernelModules = [
        "ata_piix"
        "vmw_pvscsi"
        "ahci"
        "sd_mod"
        "sr_mod"
      ];

      kernelModules = [
        "zfs"
      ];
    };

    kernelModules = [
    ];

    extraModulePackages = [ ];
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
      device = "/dev/disk/by-uuid/D139-D03C";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    "/boot/nixos" = {
      device = "/dev/disk/by-uuid/837729b1-b068-49e6-bf8f-0dc437367ac0";
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

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
