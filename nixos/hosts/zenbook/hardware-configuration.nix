{ lib, pkgs, ... }:
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
        "pcie-qcom"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
      kernelModules = [
        "kvm"
        "zfs"
      ];
    };

    kernelModules = [ ];

    kernelParams = [
      "clk_ignore_unused"
      "pd_ignore_unused"
    ];

    kernelPatches = [
      {
        name = "snapdragon-config";
        patch = null;
        extraConfig = ''
          TYPEC y
          PHY_QCOM_QMP y
          QCOM_CLK_RPM y
          MFD_QCOM_RPM y
          REGULATOR_QCOM_RPM y
          PHY_QCOM_QMP_PCIE y
          CLK_X1E80100_CAMCC y
        '';
      }
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
          # sudo dtc -I fs -O dtb /sys/firmware/devicetree/base -o ~/x1e80100-asus-zenbook-a14.dtb
          "dtbs/qcom/x1e80100-asus-zenbook-a14.dtb" = ./files/dtb/x1e80100-asus-zenbook-a14.dtb;
        };
      };
    };
  };

  hardware = {
    deviceTree = {
      enable = true;
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [
      # Copy all local device trees
      (pkgs.runCommandNoCC "devicetree" { } ''
        mkdir -p $out/lib/dtbs
        cp -r ${./files/dtb}/* $out/lib/dtbs/
      '')

      # Copy all local binary firmware blobs
      (pkgs.runCommandNoCC "firmware" { } ''
        mkdir -p $out/lib/firmware
        cp -r ${./files/firmware}/* $out/lib/firmware/
      '')
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
