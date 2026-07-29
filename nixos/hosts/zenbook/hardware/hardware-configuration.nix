{
  lib,
  pkgs,
  config,
  ...
}:
let
  isInstaller = config.networking.hostName == "installer-zenbook";
in
{
  boot = {
    supportedFilesystems = lib.mkDefault [
      "vfat"
      "btrfs"
    ];

    # Use the specific kernel tree for Zenbook A14 support
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ./kernel.nix { };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd = {
      includeDefaultModules = false;
      allowMissingModules = true;
      # Use systemd-based initrd for proper ARM64 hardware initialization and
      # device dependency resolution (proven critical for Snapdragon X Elite)
      systemd.enable = true;
      availableKernelModules = [
        # NVMe / Storage & Bus Controllers
        "nvme"
        "usb_storage"
        "usbhid"
        "hid_generic"
        "uas"
        "ax88179_178a"
        "r8152"
        "cdc_ncm"
        "cdc_ether"
        "usbnet"
        "sd_mod"
        "xhci_pci"
        "xhci_hcd"
        "xhci_plat_hcd"
        "dwc3"
        "dwc3_qcom"
        "pcie_qcom"
        "arm_smmu"
        "qcom_smd_regulator"
        "qcom_spmi_regulator"
        "qcom_geni_se"

        # Physical-layer USB transceivers/PHYs (required to detect USB devices in installer)
        "phy_qcom_qmp_usb"
        "phy_snps_eusb2"
        "phy_qcom_eusb2_repeater"
        "phy_qcom_qmp_combo"
        "ptn3222"

        # Keyboard and Touchpad (I2C HID — critical for built-in laptop input)
        "i2c_hid"
        "i2c_hid_of"
        "i2c_qcom_geni"
        "hid_multitouch"
        "evdev"

        # Filesystems
        "vfat"
        "fat"
        "iso9660"
        "squashfs"
        "overlay"
        "loop"
        "btrfs"
        "ext4"
      ]
      ++ lib.optionals (!isInstaller) [
        "drm_panel_edp"
        "drm_panel_simple"
        "drm_panel_samsung_atna33xc20"
      ];
      kernelModules = [ ];

      extraFirmwarePaths = [ ];
    };

    blacklistedKernelModules = [
      # SoundWire & Audio modules are UN-BLACKLISTED for testing Linux 7.2.0-rc5 native audio support.
      # Upstream 7.2 includes native SoundWire channel maps and audio routing in x1e80100.c and board DTS.
      #
      # If audio issues occur, un-comment the lines below to re-blacklist:
      # "snd_soc_x1e80100"
      # "snd_soc_wsa884x"
      # "snd_soc_wcd938x"
      # "snd_soc_wcd938x_sdw"
      # "snd_soc_wcd_common"
      # "soundwire_qcom"
      # "snd_soc_lpass_wsa_macro"
      # "snd_soc_lpass_rx_macro"
      # "snd_soc_lpass_tx_macro"
      # "snd_soc_lpass_va_macro"
      # "snd_soc_lpass_macro_common"

      # Blacklist remoteproc from udev auto-load. It is loaded explicitly by
      # qcom-remoteproc-load.service AFTER pd-mapper.service is running, to
      # prevent the DSP boot race condition (see resolved Issue 20).
      "qcom_q6v5_pas"
    ]
    ++ lib.optionals isInstaller [
      "typec_thunderbolt"
      "thunderbolt"
      "msm"
    ];

    kernelParams = [
      "fw_devlink=on"
      "fw_devlink.sync_state=timeout"
      "deferred_probe_timeout=30"
      "clk_ignore_unused"
      "pd_ignore_unused"
      "usbcore.quirks=0b95:1790:k"

      # Console and display
      "console=ttyMSM0,115200n8"
      "console=tty0"
      "cma=128M"
      "systemd.tpm2_wait=0"
      "nowatchdog"
      "panic_on_oops=1"
      "panic=30"
      "panic_print=0x7ff"
    ];

    extraModprobeConfig = ''
      options snd-soc-x1e80100
      softdep snd-soc-wsa884x pre: qcom_q6v5_pas
      softdep snd-soc-wcd938x-sdw pre: qcom_q6v5_pas
    '';

    kernelModules = lib.optionals (!isInstaller) [
      "msm"
    ];

    loader = {
      systemd-boot.enable = true;
      systemd-boot.editor = lib.mkForce true;
      efi = {
        canTouchEfiVariables = lib.mkForce false;
        efiSysMountPoint = lib.mkForce "/boot";
      };
    };
  };

  hardware = {
    graphics.enable = true;
    deviceTree = {
      enable = true;
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
      overlays = [
        {
          name = "ramoops-overlay";
          dtsFile = ../files/ramoops-overlay.dts;
        }
        {
          name = "cpu-cooling-overlay";
          dtsFile = ../files/cpu-cooling-overlay.dts;
        }
      ];
    };
    enableRedistributableFirmware = true;
    firmwareCompression = "none";
  };

  systemd = {
    network.networks."10-lan" = {
      matchConfig.Name = [
        "en*"
        "eth*"
      ];
      networkConfig.DHCP = "yes";
    };

    services = {
      qcom-remoteproc-load = {
        description = "Load Qualcomm remoteproc kernel modules";
        after = [
          "local-fs.target"
          "pd-mapper.service"
        ];
        requires = [
          "pd-mapper.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.kmod}/bin/modprobe qcom_q6v5_pas";
          RemainAfterExit = true;
        };
      };

      qcom-remoteproc-start = {
        description = "Start all offline Qualcomm remoteproc devices";
        after = [
          "local-fs.target"
          "pd-mapper.service"
          "qcom-remoteproc-load.service"
        ];
        requires = [
          "pd-mapper.service"
          "qcom-remoteproc-load.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "start-remoteprocs" ''
            set -uo pipefail
            shopt -s nullglob
            started=0
            for dev in /sys/class/remoteproc/remoteproc*; do
            if [ -f "$dev/state" ] && [ "$(cat "$dev/state")" = "offline" ]; then
            echo "Starting $dev" >&2
            if echo start > "$dev/state"; then
            started=$((started + 1))
            else
            echo "WARNING: Failed to start $dev" >&2
            fi
            fi
            done
            echo "Started $started remoteproc device(s)" >&2
          '';
          RemainAfterExit = true;
        };
      };
    };
  };

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot.plymouth.enable = lib.mkForce false;
  security.apparmor.enable = lib.mkForce false;

  specialisation.enable-audio.configuration = {
    system.nixos.tags = [ "enable-audio" ];
    boot.blacklistedKernelModules = lib.mkForce (
      [
        "qcom_q6v5_pas"
      ]
      ++ lib.optionals isInstaller [
        "typec_thunderbolt"
        "thunderbolt"
        "msm"
      ]
    );
  };

  specialisation.dock-fallback.configuration = {
    system.nixos.tags = [ "dock-fallback" ];
    boot.blacklistedKernelModules = [
      "ucsi_glink"
      "pmic_glink_altmode"
    ];
  };
}
