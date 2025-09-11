{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ];

  boot = {
    supportedFilesystems = [
      "vfat"
      "zfs"
    ];

    initrd = {
      availableKernelModules = [
        "nvme"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "uas"
        "sd_mod"
      ];
      kernelModules = [
        "kvm"
        "zfs"
      ];
    };

    kernelModules = [
    ];

    kernelParams = [
      "console=ttyS2,1500000n8"
    ];

    kernelPatches = [
    ];

    extraModulePackages = [ ];

    loader = {
      efi = {
        canTouchEfiVariables = true;
      };
      systemd-boot = {
        enable = true;
        extraFiles = {
          # sudo apt install device-tree-compiler
          # sudo dtc -I fs -O dtb /sys/firmware/devicetree/base -o ~/rk3588s-orangepi-5-pro.dtb;
          "dtb/base/rk3588s-orangepi-5-pro.dtb" = ./files/dtb/rk3588s-orangepi-5-pro.dtb;
        };
        extraInstallCommands = ''
          ${pkgs.coreutils}/bin/mkdir -p /boot/dtb/base
          ${pkgs.coreutils}/bin/cp -r ${config.hardware.deviceTree.package}/rockchip/* /boot/dtb/base/
          ${pkgs.coreutils}/bin/sync
        '';
      };
    };
  };

  hardware = {
    deviceTree = {
      enable = true;
      name = "rk3588s-orangepi-5-pro.dtb";
    };
    enableRedistributableFirmware = true;
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
      device = "/dev/disk/by-path/pci-0000:02:00.0-scsi-0:0:0:0-part1";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
      neededForBoot = false;
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

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
