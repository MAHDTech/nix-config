{ lib, pkgs, ... }:
{
  imports = [ ];

  boot = {
    supportedFilesystems = [
      "vfat"
      "zfs"
    ];

    # Use the specific kernel tree for Zenbook A14 support
    kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = {
        src = inputs.zenbook-linux;
        version = "6.12.0-zenbook"; # Adjust if the repo version changes
      };
    });

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
        "qcom_smd_regulator"
        "qcom_spmi_regulator"

        # Display/Framebuffer
        "fb_sys_fops"
        "syscopyarea"
        "sysfillrect"
        "sysimgblt"
      ];
      kernelModules = [
        "kvm"
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
      # "acpi=force" # Removed to allow DTB usage

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
          FRAMEBUFFER_CONSOLE y      # Enables console output on framebuffer devices
          FB_EFI y                   # Support for EFI-based framebuffer
          LOGO y                     # Displays boot logo on framebuffer

          # ARM64 console
          SERIAL_AMBA_PL011 y        # Driver for AMBA PL011 UART (serial console)
          SERIAL_AMBA_PL011_CONSOLE y # Enables console output via PL011 UART
          HVC_DCC y                  # ARM Debug Communications Channel hypervisor console
          HVC_DCC_SERIALIZE_SMP y    # Serialises SMP access for DCC console

          # Qualcomm essentials
          TYPEC y                    # USB Type-C and Power Delivery support
          PHY_QCOM_QMP y             # Qualcomm QMP PHY driver for USB/PCIE/USB3
          QCOM_CLK_RPM y             # Qualcomm RPM clock controller
          MFD_QCOM_RPM y             # Qualcomm Resource Power Manager multi-function device
          REGULATOR_QCOM_RPM y       # Qualcomm RPM voltage regulator driver
          PHY_QCOM_QMP_PCIE y        # Qualcomm QMP PCIe PHY driver
          CLK_X1E80100_CAMCC y       # Camera clock controller for Snapdragon X Elite (X1E80100)

          # Display pipeline
          DRM y                      # Direct Rendering Manager framework for GPUs
          DRM_MSM m                  # MSM DRM driver for Qualcomm Snapdragon GPUs (as module)
          DRM_PANEL_SIMPLE m         # Simple panel driver for DRM-based displays

          # ARM64 fundamentals
          ARM_SMMU y                 # ARM System Memory Management Unit support
          ARM_SMMU_V3 y              # ARM SMMU version 3 for advanced IOMMU features
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
      };
    };
  };

  hardware = {
    graphics = {
      enable = true;
    };
    deviceTree = {
      enable = true;
      # The alexVinarskis kernel builds this DTB from its own DTS sources.
      # This ensures the hardware description is perfectly synced with the drivers.
      name = "qcom/x1e80100-asus-zenbook-ux3407.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [
      (pkgs.runCommand "zenbook-firmware"
        {
          srcFirmware = ./files/firmware;
          # Audio Topology Firmware from the kernel source
          topologySrc = inputs.zenbook-linux;
        }
        ''
          # Copy Firmware Blobs from your local files (qcom, ath12k, etc.)
          mkdir -p $out/lib/firmware
          cp -r --no-preserve=mode,ownership $srcFirmware/* $out/lib/firmware/

          # Decompress zst files if necessary (Nix prefers raw or handles compression)
          find $out/lib/firmware -name "*.zst" -exec zstd -d --rm {} +

          # Copy Audio Topology Firmware specifically from kernel source
          mkdir -p $out/lib/firmware/qcom/x1e80100
          cp $topologySrc/firmware/qcom/x1e80100/*.bin $out/lib/firmware/qcom/x1e80100/
        ''
      )
    ];
  };

  # Audio (UCM files from the patched kernel tree)
  environment.etc."alsa/ucm2".source = "${inputs.zenbook-linux}/ucm2";

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

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
