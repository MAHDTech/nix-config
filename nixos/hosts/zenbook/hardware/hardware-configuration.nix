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
        kernelBuild = pkgs.callPackage ../kernel.nix { };
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
      # Issue 22: Audio playback causes instant PMIC hard reset.
      # The WSA884x speaker amplifier fails on SoundWire bus 6b10000 (Slave 0,
      # register 3452) with continuous FIFO errors from boot. Attempting audio
      # playback triggers PMIC overcurrent shutdown. The `i_accept_the_danger`
      # module parameter was removed/renamed in next-20260611 (upstream volume-
      # limiting patch may have replaced it). All audio codecs are blacklisted
      # until upstream fixes land. Bluetooth audio works via PipeWire.
      # See: ISSUES.md Issue 22, lore.kernel.org (thomas.kuang, 2026-06-08).
      # Future: try un-blacklisting only WCD938x (headphones) separately.
      "snd_soc_x1e80100" # ASoC machine driver (X1E80100 platform)
      "snd_soc_wsa884x" # WSA884x speaker amplifier — SoundWire bus errors, PMIC crash trigger
      "snd_soc_wcd938x" # WCD938x headphone codec — may work independently (untested)
      "snd_soc_wcd938x_sdw" # WCD938x SoundWire transport layer
      "snd_soc_wcd_common" # WCD common codec operations

      # Issue 23: SoundWire controller + LPASS macro modules generate a continuous
      # interrupt storm (~6,769+ IRQs on IRQ 258) from boot due to WSA884x bus errors.
      # This adds constant baseline current draw and CPU overhead that contributes
      # to PMIC OCP under sustained CPU stress. Blacklisting eliminates the storm.
      # These modules have zero users (no audio codecs loaded) so are purely waste.
      "soundwire_qcom" # Qualcomm SoundWire controller — source of the IRQ storm
      "snd_soc_lpass_wsa_macro" # LPASS WSA macro (speaker amp path)
      "snd_soc_lpass_rx_macro" # LPASS RX macro (playback path)
      "snd_soc_lpass_tx_macro" # LPASS TX macro (capture path)
      "snd_soc_lpass_va_macro" # LPASS VA macro (voice activation path)
      "snd_soc_lpass_macro_common" # LPASS macro common ops (dependency of above)

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
      # Issue 21: fw_devlink — Phase 2 (strict probe ordering with timeout safety net).
      # Research (2026-06-12) confirmed all 323 DT dependency cycles are auto-resolved
      # by the kernel on next-20260611. Zero device link failures, zero permanent
      # deferred probes. The sync_state timeout prevents indefinite blocking if any
      # consumer fails to probe (e.g. GCC waiting for all clock consumers).
      # Rollback: change fw_devlink=on → fw_devlink=permissive if boot issues occur.
      "fw_devlink=on"
      "fw_devlink.sync_state=timeout"
      "deferred_probe_timeout=30"
      # clk/pd_ignore_unused: prevent late_initcall cleanup of bootloader-enabled
      # clocks and power domains. Matches Ubuntu's linux-qcom-x1e kernel.
      "clk_ignore_unused"
      "pd_ignore_unused"
      "usbcore.quirks=0b95:1790:k"

      # Console and display
      "console=ttyMSM0,115200n8"
      "console=tty0"
      "cma=128M"
      "systemd.tpm2_wait=0" # Don't wait for fTPM during early boot (OP-TEE may be slow)
      "ip=10.10.1.91::10.10.1.1:255.255.255.0:ZENBOOK:enu2c2:none"

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
      # Suppress all platform watchdogs at boot (works on built-in drivers too)
      "nowatchdog"
    ];

    # Issue 22: Audio module configuration (currently dead code — all audio
    # modules are blacklisted above). Retained for when audio is re-enabled.
    extraModprobeConfig = ''
      options snd-soc-x1e80100
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
      overlays = [
        {
          name = "ramoops-overlay";
          dtsFile = ../files/ramoops-overlay.dts;
        }
        {
          # Issue 23: Add passive thermal trip points + cooling-maps to CPU
          # cluster thermal zones. Upstream x1e80100.dtsi has no CPU cooling-maps
          # so the cpufreq cooling devices (cpufreq-cpu0/4/8) sit idle. This
          # overlay binds them to 75°C passive trips so the step_wise governor
          # throttles CPU frequency before sustained current draw trips the PMIC.
          name = "cpu-cooling-overlay";
          dtsFile = ../files/cpu-cooling-overlay.dts;
        }
      ];
    };
    enableRedistributableFirmware = true;
    # Keep firmware uncompressed during platform bringup. OEM-signed blobs
    # (ADSP, CDSP, zap shaders) may have TrustZone hash verification.
    # The space savings (~6MB) are negligible. Revisit once stable.
    firmwareCompression = "none";
    # NOTE: hardware.firmware is managed in ./firmware/default.nix
  };

  # Audio UCM2 configuration is now upstream in alsa-ucm-conf.
  # The alexVinarskis README confirms: "Works with latest upstream alsa-ucm-config"

  systemd = {
    # Use systemd-networkd for Ethernet management
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

  # Crash capture: ensure panic settings survive into running system
  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.panic" = 30;
    "kernel.panic_print" = 2047; # 0x7ff — all info
    "kernel.sysrq" = 1; # enable all sysrq functions for emergency debugging
  };

  # Specialisations
  specialisation = {
    # Boot the system with all DSP disabled
    "disable-dsp".configuration = {
      boot = {
        blacklistedKernelModules = [
          "qcom_q6v5_pas"
        ];
        kernelParams = [
          "module_blacklist=qcom_q6v5_pas"
        ];
      };
      systemd.services = {
        qcom-remoteproc-load.enable = false;
        qcom-remoteproc-start.enable = false;
        pd-mapper.enable = false;
      };
    };

    # Boot the system with the GPU driver (msm) completely disabled
    "disable-gpu".configuration = {
      boot = {
        blacklistedKernelModules = [ "msm" ];
        kernelParams = [
          "module_blacklist=msm"
          "regulator_ignore_unused"
        ];
      };
      services = {
        greetd.enable = lib.mkForce false;
        xserver.enable = lib.mkForce false;
      };
      programs.hyprland.enable = lib.mkForce false;
      systemd.defaultUnit = lib.mkForce "multi-user.target";
    };

    # Boot the system in console text mode (but keep msm/GPU active)
    "text-mode".configuration = {
      services.greetd.enable = lib.mkForce false;
      systemd.defaultUnit = lib.mkForce "multi-user.target";
    };

    # Boot the system with both the GPU (msm) and DSPs (qcom_q6v5_pas) completely disabled
    "disable-all".configuration = {
      boot = {
        blacklistedKernelModules = [
          "msm"
          "qcom_q6v5_pas"
          "typec_thunderbolt"
          "thunderbolt"
        ];
        kernelParams = [
          "module_blacklist=msm,qcom_q6v5_pas,typec_thunderbolt,thunderbolt"
          "regulator_ignore_unused"
          "apparmor=0"
        ];
        kernelModules = lib.mkForce [ ];
      };

      services = {
        greetd.enable = lib.mkForce false;
        xserver.enable = lib.mkForce false;
        power-profiles-daemon.enable = lib.mkForce false;
        system76-scheduler.enable = lib.mkForce false;
        smartd.enable = lib.mkForce false;
        clamav = {
          daemon.enable = lib.mkForce false;
          updater.enable = lib.mkForce false;
          scanner.enable = lib.mkForce false;
        };
        cron.enable = lib.mkForce false;
        fwupd.enable = lib.mkForce false;
        acpid.enable = lib.mkForce false;
        dbus.apparmor = lib.mkForce "disabled";
      };

      programs.hyprland.enable = lib.mkForce false;

      systemd = {
        defaultUnit = lib.mkForce "multi-user.target";
        services = {
          qcom-remoteproc-load.enable = false;
          qcom-remoteproc-start.enable = false;
          pd-mapper.enable = false;
        };
      };

      security = {
        apparmor.enable = lib.mkForce false;
        lsm = lib.mkForce [ ];
      };
    };

    # Match the live installer environment as closely as possible while
    # booting from NVMe. This isolates NVMe I/O and background services
    # as the variable — if stress-ng still crashes here but works on the
    # USB installer, the difference is NVMe/PCIe power draw.
    "installer-mimic".configuration = {
      boot = {
        blacklistedKernelModules = [
          "msm"
          "qcom_q6v5_pas"
          "typec_thunderbolt"
          "thunderbolt"
          "pstore_blk" # Not present on installer
          "netconsole" # Not present on installer
          "drm_panel_edp" # Not loaded in installer initrd
          "drm_panel_simple"
          "drm_panel_samsung_atna33xc20"
        ];
        kernelParams = [
          "module_blacklist=msm,qcom_q6v5_pas,typec_thunderbolt,thunderbolt,pstore_blk"
          "regulator_ignore_unused"
          # Minimize NVMe power: disable autonomous power state transitions
          "nvme_core.default_ps_max_latency_us=0"
          "iommu.default_domain_type=passthrough"
        ];
        kernelModules = lib.mkForce [ ];

        # Override SOE sysctl to match installer defaults
        kernel.sysctl = {
          # Installer uses kernel defaults (not 1)
          "vm.compact_unevictable_allowed" = lib.mkForce 0;
          # Installer uses kernel default (60)
          "vm.swappiness" = lib.mkForce 60;
        };
      };

      # Persistent journald to capture oops logs on NVMe
      services.journald = {
        storage = "persistent";
        extraConfig = ''
          RuntimeMaxUse=50M
        '';
      };

      services = {
        greetd.enable = lib.mkForce false;
        xserver.enable = lib.mkForce false;
        power-profiles-daemon.enable = lib.mkForce false;
        system76-scheduler.enable = lib.mkForce false;
        smartd.enable = lib.mkForce false; # Prevents NVMe SMART polling
        clamav = {
          daemon.enable = lib.mkForce false;
          updater.enable = lib.mkForce false;
          scanner.enable = lib.mkForce false;
        };
        cron.enable = lib.mkForce false;
        fwupd.enable = lib.mkForce false;
        acpid.enable = lib.mkForce false;
        dbus.apparmor = lib.mkForce "disabled";
        #batteryNotifier.enable = lib.mkForce false;
      };

      programs.hyprland.enable = lib.mkForce false;

      # Disable zram swap (not present on installer)
      zramSwap.enable = lib.mkForce false;

      # Disable plymouth (not present on installer, adds 'splash' kernel param)
      boot.plymouth.enable = lib.mkForce false;

      systemd = {
        defaultUnit = lib.mkForce "multi-user.target";
        services = {
          qcom-remoteproc-load.enable = false;
          qcom-remoteproc-start.enable = false;
          pd-mapper.enable = false;
          # Disable telemetry (not present on installer) but KEEP netconsole enabled
          pmic-telemetry-logger.enable = lib.mkForce false;
        };
      };

      security = {
        apparmor.enable = lib.mkForce false;
        # Match installer LSM list exactly: landlock,yama,bpf (no apparmor)
        lsm = lib.mkForce [
          "landlock"
          "yama"
          "bpf"
        ];
      };
    };

    # Boot with ACPI interpreter forced on (diagnostic only).
    # Enables acpidump to extract ACPI tables (DSDT/SSDT) which
    # contain Windows PEP power limit definitions. The UEFI firmware
    # exposes ACPI 2.0 at 0xd47d3018 but Linux disables the
    # interpreter on DT-booted ARM64 by default.
    # WARNING: Qualcomm ACPI tables are designed for Windows. Some
    # ACPI methods may cause errors or unexpected behaviour on Linux.
    # Use for table extraction only, then reboot to normal entry.
    "force-acpi".configuration = {
      boot.kernelParams = [ "acpi=force" ];
    };
  };

  # Force-disable Plymouth and AppArmor at the parent configuration level
  # to completely exclude them from the shared boot initrd.
  boot.plymouth.enable = lib.mkForce false;
  security.apparmor.enable = lib.mkForce false;
}
