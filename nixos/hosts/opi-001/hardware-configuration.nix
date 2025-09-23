{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ];

  powerManagement = {
    cpuFreqGovernor = lib.mkDefault "ondemand";
  };

  boot = {
    supportedFilesystems = [
      "vfat"
      "fat32"
      "exfat"
      "ext4"
      "zfs"
    ];

    initrd = {
      includeDefaultModules = lib.mkForce false;
      availableKernelModules = lib.mkForce [
        "dm_crypt" # LUKS
        "dm_mod" # LUKS
        "hid"
        "input_leds"
        "mmc_block"
        "nvme"
        "sd_mod"
        "uas"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
      kernelModules = [
        "kvm"
        "zfs"
      ];
    };

    kernelModules = [
    ];

    kernelParams = [
      "rootwait"

      "earlycon" # Enable boot messages via debug port
      "consoleblank=0" # disable console blanking(screen saver)
      "console=ttyS2,1500000" # debug serial port
      "console=tty1" # HDMI

      # docker optimizations
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
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
          # TODO: Test custom device tree
          # sudo apt install device-tree-compiler
          # sudo dtc -I fs -O dtb /sys/firmware/devicetree/base -o ~/rk3588s-orangepi-5-pro.dtb;
          #"dtb/base/rk3588s-orangepi-5-pro.dtb" = ./files/dtb/rk3588s-orangepi-5-pro.dtb;
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
      name = "rockchip/rk3588s-orangepi-5-pro.dtb";
      overlays = [
      ];
    };
    enableRedistributableFirmware = lib.mkForce true;
    firmware = [
      (pkgs.callPackage ./firmware.nix { })
    ];
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
