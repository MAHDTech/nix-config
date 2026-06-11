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
      # (Not needed anymore since remoteproc and Type-C modules are moved to Stage 2)
      extraFirmwarePaths = [ ];
    };

    blacklistedKernelModules = [
      # Blacklist audio codecs — ADSP starts for battery/USB-C PD but the audio
      # subsystem (SoundWire + WCD938x + WSA884x + APM) causes qcom-apm CMD
      # timeouts that trigger cascading USB/PMIC failures.
      "snd_soc_x1e80100" # machine driver
      "snd_soc_wsa884x" # speaker amplifier codec
      "snd_soc_wcd938x" # headphone codec
      "snd_soc_wcd938x_sdw" # WCD938x SoundWire transport
      "snd_soc_wcd_common" # WCD common ops
    ]
    ++ lib.optionals isInstaller [
      "typec_thunderbolt"
      "thunderbolt"
      "msm"
    ];

    kernelParams = [
      # Platform workarounds — these match the STABLE installer config exactly.
      # The installer survived a full kernel compilation; every installed boot crashed.
      # efi=noruntime: CRITICAL on ARM64 Qualcomm — EFI runtime services cause hard
      # crashes when the kernel accesses UEFI variables/services post-boot.
      "efi=noruntime"
      "fw_devlink=permissive"
      "clk_ignore_unused"
      "pd_ignore_unused"
      "regulator_ignore_unused"
      "pcie_aspm=off"
      "usbcore.quirks=0b95:1790:k"

      # Console and display
      "console=ttyMSM0,115200n8"
      "console=tty0"
      "cma=128M"
      "video=efifb"
      "fbcon=map:0"
      "arm64.nopauth"
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
      # pstore-blk: persistent crash store on dedicated 16M partition (survives reboot + power loss)
      # disko labels partitions as disk-{name}-{part}
      "pstore_blk.blkdev=/dev/disk/by-partlabel/disk-main-pstore"
    ];

    # Speaker safety interlock — required by snd-soc-x1e80100 driver
    extraModprobeConfig = ''
      options snd-soc-x1e80100 i_accept_the_danger=1
      # SoundWire boot ordering: ensure ADSP remoteproc loads before speaker codec
      softdep snd-soc-wsa884x pre: qcom_q6v5_pas
      softdep snd-soc-wcd938x-sdw pre: qcom_q6v5_pas
    '';

    # netconsole moved to systemd service (netconsole.nix) — loads after network is up
    kernelModules = lib.optionals (!isInstaller) [
      "msm"
      "pstore_blk"
    ];

    # Modern boot management
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
    # We restore the external DTB because the UEFI DTB might be missing nodes
    # causing instant reboots or missing dependencies for USB/DSPs.
    deviceTree = {
      enable = true;
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
      overlays = [ ];
    };
    enableRedistributableFirmware = true;
    firmwareCompression = "none";
    firmware = [
      # OEM firmware: device-specific blobs NOT available in upstream linux-firmware.
      # Provides:
      #   - ADSP/CDSP (qcadsp8380.mbn, qccdsp8380.mbn)
      #   - Video codec (qcvss8380.mbn)
      #   - AV1 decoder (qcav1e8380.mbn)
      #   - pd-mapper descriptors (*.jsn)
      #   - GPU SQE microcode
      #
      # linux-firmware (via enableRedistributableFirmware)
      # Provides:
      #   - WiFi
      #   - Bluetooth
      #   - audio topology
      #   - GPU GMU/ZAP shaders
      #   - and other SoC-generic firmware.
      (pkgs.callPackage ./firmware/asus.nix { })
    ];
  };

  # Audio UCM2 configuration is now upstream in alsa-ucm-conf.
  # The alexVinarskis README confirms: "Works with latest upstream alsa-ucm-config"

  # GPU frequency cap removed — SCMI powercap + LMH now manage power budgets through firmware.
  # Previous 390 MHz cap was a workaround for PMIC overcurrent resets caused by missing
  # power management configuration, not a hardware limitation.
  # If instability returns, the power-safe specialisation below restores the cap.

  systemd = {
    # Use systemd-networkd for Ethernet management
    network.networks."10-lan" = {
      matchConfig.Name = [
        "en*"
        "eth*"
      ];
      networkConfig.DHCP = "yes";
    };

    services.qcom-remoteproc-start = {
      description = "Start all offline Qualcomm remoteproc devices";
      after = [
        "local-fs.target"
        "systemd-udev-settle.service"
        "pd-mapper.service"
      ];
      requires = [
        "pd-mapper.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'for dev in /sys/class/remoteproc/remoteproc*; do if [ -f \"$dev/state\" ] && [ \"$(cat \"$dev/state\")\" = \"offline\" ]; then echo start > \"$dev/state\"; fi; done'";
        RemainAfterExit = true;
      };
    };
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

  # Specialisations
  specialisation = {
    # Boot the system with the GPU driver (msm) completely disabled
    "no-gpu".configuration = {
      boot.blacklistedKernelModules = [ "msm" ];
    };

    # Boot the system in text mode for stability diagnostics
    "text-mode".configuration = {
      boot.blacklistedKernelModules = [
        "msm"
        "thunderbolt"
        "typec_thunderbolt"
        "ath12k_wifi7_pci"
        "ath12k"
      ];
      boot.kernelParams = [
        "systemd.unit=multi-user.target"
      ];
    };

    # ADSP fully blacklisted, all other power improvements kept.
    # No audio, no battery monitoring, but no ADSP crash risk.
    # Tests: are the power management improvements (no regulator_ignore_unused,
    # SCMI powercap, PCIe ASPM) stable WITHOUT the ADSP?
    "no-adsp".configuration = {
      boot.blacklistedKernelModules = [ "qcom_q6v5_pas" ];
      boot.kernelParams = [
        "module_blacklist=qcom_q6v5_pas"
      ];
    };

    # Conservative power caps as a rollback safety net.
    # Restores the old CPU (1.92 GHz) and GPU (390 MHz) caps, ADSP blacklist,
    # and *_ignore_unused params. Use this if the default boot is unstable.
    "power-safe".configuration = {
      boot.blacklistedKernelModules = [ "qcom_q6v5_pas" ];
      boot.kernelParams = [
        "module_blacklist=qcom_q6v5_pas"
        "clk_ignore_unused"
        "pd_ignore_unused"
        "regulator_ignore_unused"
      ];
      services.udev.extraRules = ''
        SUBSYSTEM=="devfreq", KERNEL=="3d00000.gpu", ACTION=="add", ATTR{max_freq}="390000000"
      '';
      systemd.services.limit-cpu-freq = {
        description = "Limit CPU max frequency (power-safe fallback)";
        after = [ "systemd-udev-settle.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1920000 | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq > /dev/null'";
          RemainAfterExit = true;
        };
      };
    };
  };

}
