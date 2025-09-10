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
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "uas"
        "sd_mod"

        # ARM/Qualcomm
        "arm_smmu"
        "qcom_geni_se"
        "qcom_geni_i2c"
        "qcom_geni_spi"
        "qcom_smd_regulator"
        "qcom_spmi_regulator"

        # Display/Framebuffer
        "simplefb"
        "efifb"
        "fb_sys_fops"
        "syscopyarea"
        "sysfillrect"
        "sysimgblt"
      ];
      kernelModules = [
        #"kvm"
        "zfs"
      ];
    };

    kernelModules = [
      # ARM64
      "msm"
      "panel_simple"

      # Qualcomm
      "qcom_q6v5_mss"
      "qcom_common"
      "qcom_glink_smem"
      "qcom_sysmon"
    ];

    kernelParams = [
      # Boot parameters for Snapdragon
      "clk_ignore_unused"
      "pd_ignore_unused"

      # Console output
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "earlyprintk"

      # Framebuffer
      "cma=128M"
      "video=efifb"
      "fbcon=map:0"

      # ARM64 specific
      "arm64.nopauth"
      "acpi=force"

      # Debug (remove after it works)
      "loglevel=7"
      "debug"
      "ignore_loglevel"
    ];

    kernelPatches = [
      {
        name = "snapdragon-config";
        patch = null;
        extraConfig = ''
          # Framebuffer for installer
          FRAMEBUFFER_CONSOLE y
          FB_EFI y
          FB_SIMPLE y
          LOGO y

          # ARM64 console
          SERIAL_AMBA_PL011 y
          SERIAL_AMBA_PL011_CONSOLE y
          HVC_DCC y
          HVC_DCC_SERIALIZE_SMP y

          # Qualcomm essentials
          TYPEC y
          PHY_QCOM_QMP y
          QCOM_CLK_RPM y
          MFD_QCOM_RPM y
          REGULATOR_QCOM_RPM y
          PHY_QCOM_QMP_PCIE y
          CLK_X1E80100_CAMCC y

          # Display pipeline
          DRM y
          DRM_MSM y
          DRM_PANEL_SIMPLE y

          # ARM64 fundamentals
          ARM_SMMU y
          ARM_SMMU_V3 y
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
          "dtbs/x1e80100-asus-zenbook-a14.dtb" = ./files/dtbs/x1e80100-asus-zenbook-a14.dtb;
        };
      };
    };
  };

  hardware = {
    deviceTree = {
      enable = true;
      name = "x1e80100-asus-zenbook-a14.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [
      (pkgs.runCommandNoCC "zenbook-custom-firmware"
        {
          srcFirmware = ./files/firmware;
        }
        ''
          # Copy Firmware Blobs
          mkdir -p $out/lib/firmware
          cp -r --no-preserve=mode,ownership $srcFirmware/* $out/lib/firmware/
        ''
      )
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
