{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  isInstaller = config.networking.hostName == "installer-zenbook";
in
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkDefault [
      "vfat"
      "btrfs"
    ];

    # Use the specific kernel tree for Zenbook A14 support
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ../kernel.nix { inherit inputs; };
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
        # vfat/fat: required for the ESP (/boot) — CONFIG_VFAT_FS is =m in the
        # defconfig. With includeDefaultModules=false these must be explicit.
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
        # USB Type-C power state, alternate modes, and PMIC GLINK mapping (requires ADSP/remoteprocs)
        "pmic_glink"
        "pmic_glink_altmode"
        "qcom_pmic_glink"
        "qcom_pmic_typec"
        "ps883x"
        # ucsi_glink: UCSI over Qualcomm PMIC glink — USB-C PD and DP alt-mode.
        # Kernel config symbol: UCSI_PMIC_GLINK (=m in defconfig; enforced in kernel.nix).
        # Linux module name on-disk is ucsi_glink.
        "ucsi_glink"
        "typec_ucsi"

        # WiFi/BT power sequencing
        # ath12k_wifi7_pci: alexVinarskis patch set reorganises ath12k into a wifi7/
        # subdirectory. Confirmed on live device: driver is ath12k_wifi7_pci.
        "ath12k_wifi7_pci"
        "pwrseq_qcom_wcn"

        # Early display — drm panel drivers are forced =y (built-in) in kernel.nix.
        # Note: drm_simpledrm is NOT a separate loadable module in this kernel
        # (confirmed on live device — efifb handles early display, MSM DRM takes over).
        # Panel entries below are belt-and-suspenders in case of future =m regressions.
        "drm_panel_edp"
        "drm_panel_simple"
        "drm_panel_samsung_atna33xc20"
      ];
      kernelModules = [ ];

      # Load crucial platform firmware directly in stage 1 to prevent driver crashes
      extraFirmwarePaths = [
        "qcom"
        "ath12k"
      ];
    };

    blacklistedKernelModules = [
      "typec_thunderbolt"
      "thunderbolt"
    ]
    ++ lib.optionals isInstaller [
      "qcom_q6v5_pas"
      "msm"
    ];

    kernelParams = [
      "clk_ignore_unused"
      "pd_ignore_unused"
      "regulator_ignore_unused"
      "console=ttyMSM0,115200n8"
      "console=tty0"
      "cma=128M"
      "video=efifb"
      "fbcon=map:0"
      "arm64.nopauth"
      "pcie_aspm=off"
      "efi=noruntime"
      "usbcore.quirks=0b95:1790:k"
      "systemd.tpm2_wait=0"
      "ip=10.10.1.91::10.10.1.1:255.255.255.0:zenbook:enu2c2:none"

      # Crash capture: ramoops is now in DTB overlay (ARM64 ignores memmap=)
      # Escalate oops to panic so pstore gets flushed
      "panic_on_oops=1"
      # Auto-reboot 30 seconds after panic
      "panic=30"
      # Print all useful info on panic (tasks, memory, timers, locks, ftrace, all CPUs)
      "panic_print=0x7ff"
      # Full kernel log verbosity for crash forensics
      "loglevel=7"
    ];

    # Speaker safety interlock — required by snd-soc-x1e80100 driver
    extraModprobeConfig = ''
      options snd-soc-x1e80100 i_accept_the_danger=1
      options netconsole netconsole=@/enu2c2,6666@10.10.1.97/
    '';

    kernelModules = [
      "netconsole"
    ]
    ++ lib.optionals (!isInstaller) [
      "qcom_q6v5_pas"
      "msm"
    ];

    # Modern boot management
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = lib.mkForce "/boot";
      };
    };
  };

  systemd.services.gpu-frequency-cap = {
    description = "Limit Adreno GPU max frequency to prevent overcurrent crashes";
    after = [ "systemd-udev-settle.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ -f /sys/class/devfreq/3d00000.gpu/max_freq ]; then echo 390000000 > /sys/class/devfreq/3d00000.gpu/max_freq; fi'";
      RemainAfterExit = true;
    };
  };

  hardware = {
    graphics.enable = true;
    deviceTree = {
      enable = true;
      # The alexVinarskis kernel builds this DTB from its own DTS sources.
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
      overlays = [
        {
          name = "ramoops-overlay";
          dtsFile = ../files/ramoops-overlay.dts;
        }
      ];
    };
    enableRedistributableFirmware = true;
    firmware = [
      (pkgs.callPackage ./firmware.nix { })
      (pkgs.callPackage ./firmware-windows.nix { })
      (pkgs.runCommand "zenbook-initrd-firmware" { } ''
        mkdir -p $out/lib/firmware/qcom
        mkdir -p $out/lib/firmware/ath12k/WCN7850/hw2.0

        # Copy and decompress wireless regulatory database to resolve WiFi channel scan issues
        mkdir -p $out/lib/firmware
        cp -f ${pkgs.wireless-regdb}/lib/firmware/regulatory.db* $out/lib/firmware/

        # Copy GPU firmware (both Elite and Plus variants)
        cp -r ${pkgs.linux-firmware}/lib/firmware/qcom/gen70500_* $out/lib/firmware/qcom/
        cp -r ${pkgs.linux-firmware}/lib/firmware/qcom/gen71500_* $out/lib/firmware/qcom/
        mkdir -p $out/lib/firmware/qcom/x1p42100
        cp -r ${pkgs.linux-firmware}/lib/firmware/qcom/x1p42100/gen71500_* $out/lib/firmware/qcom/x1p42100/

        # Copy ath12k WiFi firmware
        cp -r ${pkgs.linux-firmware}/lib/firmware/ath12k/WCN7850/hw2.0/* $out/lib/firmware/ath12k/WCN7850/hw2.0/

        # Copy audio topology file to both expected paths (directly under x1e80100/x1p42100 and inside ASUSTeK/zenbook-a14)
        for soc in x1e80100 x1p42100; do
          mkdir -p $out/lib/firmware/qcom/$soc/ASUSTeK/zenbook-a14
          if [ -f ${pkgs.linux-firmware}/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin ]; then
            cp ${pkgs.linux-firmware}/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin $out/lib/firmware/qcom/$soc/
            cp ${pkgs.linux-firmware}/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin $out/lib/firmware/qcom/$soc/ASUSTeK/zenbook-a14/
          elif [ -f ${pkgs.linux-firmware}/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin.zst ]; then
            ${pkgs.zstd}/bin/zstd -d ${pkgs.linux-firmware}/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin.zst -o $out/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin
            cp $out/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin $out/lib/firmware/qcom/$soc/ASUSTeK/zenbook-a14/
          elif [ -f ${pkgs.linux-firmware}/lib/firmware/qcom/x1e80100/X1E80100-ASUS-Zenbook-A14-tplg.bin.zst ]; then
            ${pkgs.zstd}/bin/zstd -d ${pkgs.linux-firmware}/lib/firmware/qcom/x1e80100/X1E80100-ASUS-Zenbook-A14-tplg.bin.zst -o $out/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin
            cp $out/lib/firmware/qcom/$soc/X1E80100-ASUS-Zenbook-A14-tplg.bin $out/lib/firmware/qcom/$soc/ASUSTeK/zenbook-a14/
          fi
        done

        # Decompress any .zst files we copied to ensure they are raw .fw/bin files
        find $out -name "*.zst" -exec ${pkgs.zstd}/bin/zstd -d --rm {} \;

        # Make files writeable so we can remove them
        chmod -R +w $out

        # Clean up text files and symlinks to satisfy Nix's broken symlinks check
        find $out -type l -exec rm -f {} +
        find $out -name "*.txt" -exec rm -f {} +
      '')
    ];
  };

  # Audio UCM2 configuration is now upstream in alsa-ucm-conf.
  # The alexVinarskis README confirms: "Works with latest upstream alsa-ucm-config"

  # Use systemd-networkd for Ethernet management
  systemd.network.networks."10-lan" = {
    matchConfig.Name = [
      "en*"
      "eth*"
    ];
    networkConfig.DHCP = "yes";
  };

  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Crash capture: ensure panic settings survive into running system
  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.panic" = 30;
    "kernel.panic_print" = 2047; # 0x7ff — all info
    "kernel.sysrq" = 1; # enable all sysrq functions for emergency debugging
  };
}
