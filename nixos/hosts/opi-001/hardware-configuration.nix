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
        "analogix_dp"
        "dm_crypt" # LUKS
        "dm_mod" # LUKS
        "dw_hdmi" # Display/HDMI
        "dw_mmc_rockchip"
        "hid"
        "input_leds"
        "mmc_block"
        "mmc_core"
        "nvme"
        "pcie_rockchip_host"
        "phy_rockchip_pcie"
        "pwm-rockchip"
        "rockchip-rng"
        "sd_mod"
        "sdhci"
        "sdhci-pci"
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
      "brcmfmac" # Broadcom WiFi
      "btusb" # Bluetooth USB
      #"r8125" # Realtek Ethernet
      #"r8169" # Realtek Ethernet
      "motorcomm" # Motorcomm YT8531 Ethernet
      "rkvdec" # Rockchip Video Decoder
      "rknpu" # Rockchip Neural Processing Unit
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

      # PCI-E disable power management
      "pcie_aspm=off"
    ];

    kernelPatches = [
      {
        name = "rockchip-options";
        patch = null; # No patch file, just config overrides
        extraConfig = ''
          # Enable access to staging drivers
          STAGING y
          STAGING_MEDIA y

          # Architecture
          ARCH_ROCKCHIP y

          # Rockchip specific options
          DRM_ROCKCHIP y
          PCIE_ROCKCHIP_HOST y
          PHY_ROCKCHIP_PCIE y
          ROCKCHIP_DW_HDMI y
          ROCKCHIP_IOMMU y
          ROCKCHIP_VOP2 y

          # Dependencies
          MDIO_BUS y
          MEDIA_CONTROLLER y
          PHYLIB y
          STMMAC_ETH y
          V4L2_H264 m
          V4L2_MEM2MEM_DEV m
          V4L2_VP9 m
          VIDEOBUF2_DMA_CONTIG m
          VIDEOBUF2_VMALLOC m

          # Rockchip Video Decoder
          VIDEO_ROCKCHIP_VDEC m

          # Panfrost GPU Driver for Mali G610
          DRM_PANFROST y

          # Motorcomm YT8531 Ethernet
          MOTORCOMM_PHY m
        '';
      }
    ];

    extraModulePackages = [ ];

    loader = {
      efi = {
        canTouchEfiVariables = true; # edk2 firmware
      };
      systemd-boot = {
        enable = true;
        extraFiles = {
          # TODO: Test custom device tree
          # sudo apt install device-tree-compiler
          # sudo dtc -I fs -O dtb /sys/firmware/devicetree/base -o ~/rk3588s-orangepi-5-pro.dtb;
          "dtbs/rockchip/rk3588s-orangepi-5-pro.dtb" = ./files/dtb/rk3588s-orangepi-5-pro.dtb;
        };
        extraInstallCommands = ''
          # Create the directory for device tree blobs
          ${pkgs.coreutils}/bin/mkdir -p /boot/dtbs

          # Only copy the device tree blobs if they don't conflict with custom ones already present.
          for DTB in ${config.hardware.deviceTree.package}/rockchip/*.dtb;
          do
            if [ ! -f "/boot/dtbs/rockchip/''${DTB}" ];
            then
              ${pkgs.coreutils}/bin/echo "Copying ''${DTB} to /boot/dtbs/rockchip/"
              ${pkgs.coreutils}/bin/cp "''${DTB}" /boot/dtbs/rockchip/
            else
              ${pkgs.coreutils}/bin/echo "Skipping ''${DTB} as it already exists in /boot/dtbs/rockchip/"
            fi
          done
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
      pkgs.armbian-firmware
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
