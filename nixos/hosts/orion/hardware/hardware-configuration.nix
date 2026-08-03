{
  config,
  lib,
  pkgs,
  ...
}:
let
  cix-noe-umd = pkgs.callPackage ../packages/cix-noe-umd.nix { };
  cix-dsp-firmware = pkgs.callPackage ../packages/cix-dsp-firmware.nix { };
  sky1-firmware = pkgs.callPackage ../packages/sky1-firmware.nix { };
  # EDK2 BIOS version for the BIOS update script
  # TODO: Update when Radxa ships EDK2 with the IORT SMMU fix
  orionBiosVersion = "1.2.1";

  # Detect installer mode — when true, only load critical drivers
  # (NVMe, USB, ethernet) and skip GPU, display, NPU, VPU, Type-C
  isInstaller = config.networking.hostName == "installer-orion";
in
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
    ];

    # Custom patched mainline v7.0 kernel is configured dynamically
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ./kernel { };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd = {
      includeDefaultModules = false;
      availableKernelModules = [
        "nvme"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "xhci_hcd"
        "xhci_plat_hcd"
        "uas"
        "r8169" # Realtek RTL8126 5GbE (in-kernel driver, added RTL8126 support in 7.x)
        "r8152" # Realtek USB Ethernet (fallback for USB dongles)
        "ax88179_178a" # ASIX AX88179 USB Ethernet
        "cdc_ncm" # CDC NCM USB Ethernet
        "cdc_ether" # CDC Ether USB Ethernet
        "usbnet" # USB network core
        # Cadence cdns3 USB controller (PCIe-attached on CIX P1)
        # Live device shows cdns3_pci_wrap / cdnsp_udc_pci loading, not generic dwc3
        "cdns3-pci-wrap"
      ];
      kernelModules = [ ];
    };

    # Load after boot (not needed during initrd)
    #
    # MAINLINE-FIRST STAGE 1: the CIX peripheral drivers are not built, because
    # mainline does not carry them and their patches are disabled in
    # ./kernel/default.nix while we establish that a mainline kernel boots.
    # Re-add each entry as its patch is rebased and verified:
    #
    #   "linlon-dp" "trilin-dpsub"   display pipeline
    #   "typec" "typec_ucsi" "typec_displayport"
    #   "aipu"                       NPU
    #   "amvx"                       VPU
    #
    # panthor IS in mainline, but without the Sky1 SCMI/DVFS glue it has no
    # power domain to attach to, so it stays out until 06-gpu-panthor returns.
    kernelModules = lib.optionals (!isInstaller) [
      "kvm"
      # USB platform glue. Loaded here so USB is up during boot rather than
      # waiting on a hotplug event -- a keyboard has to exist before the login
      # prompt, not after someone plugs something in.
      "cdnsp_sky1"
      # NPU. Loaded at boot so /dev/aipu exists without anyone running
      # modprobe -- the stress tooling expects it present.
      "armchina_npu"
      # Display. linlon_dp is the DRM master and uses the component framework,
      # so it waits for trilin_dpsub to register before binding; both are listed
      # so neither depends on udev ordering. This replaces simpledrm as the
      # console, at the monitor's native resolution rather than a fixed 1080p.
      "linlon_dp"
      "trilin_dpsub"
      "sky1_drm"
    ];

    # Prevent panfrost from loading (wrong driver for Immortalis-G720 CSF, use panthor)
    # Belt-and-suspenders: also add via module_blacklist= kernel param below
    #
    # iwlwifi: on the mainline kernel this panics the machine during boot.
    # Captured via efi_pstore:
    #
    #   Kernel panic - not syncing: Asynchronous SError Interrupt
    #   CPU: 0 PID: 513 Comm: (udev-worker)
    #     el1h_64_error
    #     iwl_pci_probe+0xf0/0x188 [iwlwifi]
    #     local_pci_probe -> pci_device_probe -> ... -> finit_module
    #
    # The Intel AX210 sits on a0c0000.pcie (PCI domain 0002:60). The downstream
    # driver powers it through a "wlan-en" regulator — 6.19 logs
    # "sky1-pcie a0c0000.pcie: no wlan-en regulator found" — and mainline's
    # pci-sky1.c has no such handling. So the card is unpowered, iwlwifi's first
    # MMIO read goes to dead hardware, and an asynchronous SError is fatal.
    #
    # Wi-Fi is not in use here (wlan0 is down; the box is on wired enP3p1s0), so
    # blacklisting is the right trade for now. The real fix is to port the
    # wlan-en regulator support as an additive patch, at which point drop this.
    # armchina_npu is no longer blacklisted: it has bound cleanly and been
    # exercised. The hardware identifies itself (Zhouyi V3, 3 cores, 4 TECs),
    # allocates from its carveout, answers register reads and advances its tick
    # counter, so the reason for the blacklist -- an untested driver touching
    # SMC power domains and MMIO on a possibly-unpowered block -- is spent.
    # cdnsp-sky1 is NO LONGER blacklisted: USB now works end to end. The
    # keyboard, a card reader and two hubs all enumerate at 480 Mb/s.
    #
    # It stays a MODULE rather than going back to =y. The earlier boot lockup
    #
    #   Sending NMI from CPU 0 to CPUs 7:
    #   NMI backtrace for cpu 7 skipped
    #
    # is understood now -- cdnsp-plat never called cdns_core_init_role(), so
    # cdns->roles[] stayed empty and any teardown walked a NULL role pointer
    # (the same fault later captured as a panic in cdns_role_stop). That is
    # fixed. But "understood" is not "proven at boot", and the difference
    # between the two is a physical trip to the machine. As a module, udev
    # loads it during boot so USB is available without anyone typing modprobe,
    # and a probe that misbehaves stalls a udev worker instead of wedging the
    # kernel. Revisit =y once it has come up cleanly across a few boots.
    # The display drivers are no longer blacklisted: the pipeline works.
    #
    #   linlondp 141d0000.disp-controller -> card1, connectors=3
    #   trilin-dptx-cix 14224000.dp: main link training done! rate:270000 lanes:4
    #   card1-DP-1: connected, 3440x1440 native, 384 bytes of EDID
    #   fb0: linlondpdrmfb 3440x1440
    #
    # They are still modules, and are loaded from kernelModules below rather
    # than left to udev, so the order is explicit.
    # iwlwifi is blacklisted again. Unblacklisting it made the machine
    # unbootable and needed a power cycle and a boot-menu pick to recover.
    #
    # The reasoning for lifting it was that vdd_3v3_wlan -- added to get
    # Bluetooth working -- powers the same AX210, so the unpowered-card cause
    # of the original SError was gone. That was half right and wholly wrong:
    # Bluetooth is the card's USB half, Wi-Fi is its PCIe half. Powering the
    # card fixed the USB side without demonstrating anything about PCIe, and
    # "the card is powered" was treated as "iwlwifi will probe", which are
    # different claims.
    #
    # It stays a module and stays blacklisted, so any future attempt is an
    # insmod over SSH -- the same pattern used for the NPU, the USB glue and
    # the display drivers, each of which caught a fatal probe without costing
    # a trip to the machine. That pattern existed and was not applied here.
    blacklistedKernelModules = [
      "panfrost"
      "iwlwifi"
    ];

    # Boot diagnostics have been removed now that 7.2 boots and the hardware
    # works. They were doing active harm at the end: earlycon + keep_bootcon +
    # ignore_loglevel print every kernel message straight onto the EFI
    # framebuffer, which is the same VT tuigreet draws the login prompt on, so
    # the login screen was buried under a running commentary of USB probing.
    #
    # What they bought while they were here, for the record: the mailbox
    # -EINVAL, the AUDSS SError, the iwlwifi SError, the reset-controller
    # -EPROBE_DEFER cascade and the panthor abort were all found this way.
    # Restore them (earlycon=efifb, keep_bootcon, ignore_loglevel,
    # consoleLogLevel = 7) if a future boot goes dark again.
    #
    # pstore keeps working regardless -- it is what captured the cdns_role_stop
    # panic -- so a crash is still recorded without shouting at the console.

    kernelParams = [

      # NOTE: iteration 5 tried "initcall_blacklist=sysfb_init" here, on the
      # theory that simpledrm was stealing the EFI framebuffer and blanking the
      # screen. Rejected — video of a 7.2 boot shows the display dying exactly
      # as arm-smmu-v3 initialises, and dmesg from the WORKING 6.19 kernel shows
      # the identical fault:
      #   arm-smmu-v3 b1b0000.iommu: event: F_TRANSLATION
      #     client: 141d0000.disp-controller sid: 0x18 "Input address caused fault"
      #   arm-smmu-v3 b1b0000.iommu: auto-suppressing events for sid 0x18
      # The display controller is still scanning out the framebuffer the firmware
      # left it, and the SMMU has no mapping for that address, so scanout stops.
      # This happens on every kernel here — the blank screen is normal on this
      # board and is NOT the boot failure.

      "console=ttyAMA0,115200n8"
      "console=tty0"
      # NOTE: `fbcon=map:1` temporarily removed. It sends the console to fb1
      # instead of fb0, which is counterproductive while we are trying to keep
      # output on the EFI framebuffer.
      "acpi=off" # Force Device Tree by completely ignoring the EDK2 BIOS ACPI tables
      # nowatchdog restored: it disables the kernel soft/hard lockup detectors.
      # Those were wanted while chasing silent hangs -- they are what printed
      # the "Sending NMI from CPU 0 to CPUs 7" trace for the USB boot lockup --
      # but with the machine stable they are just a source of false positives
      # under heavy load, which the UAT deliberately generates.
      "nowatchdog"
      # Belt-and-suspenders panfrost blacklist via kernel param (NixOS option alone not sufficient)
      # iwlwifi included here as well as in blacklistedKernelModules: an SError
      # during iwl_pci_probe is fatal, so it must never load, not merely be
      # discouraged. See the note on blacklistedKernelModules above.
      "module_blacklist=panfrost,iwlwifi"
      # clk_ignore_unused: prevent kernel from disabling clocks before drivers initialise
      # Required on CIX P1 to avoid slow boot and hardware init races
      "clk_ignore_unused"
      # Use identity (passthrough) IOMMU domains by default, so devices are not
      # translated by the SMMU and early-boot DMA cannot fault.
      #
      # This previously read `iommu.default_domain_type=passthrough`, which is
      # NOT a kernel parameter — it is a sysfs attribute
      # (/sys/.../iommu_group/type). drivers/iommu/iommu.c registers exactly two
      # early_params, `iommu.passthrough` and `iommu.strict`, so the old line was
      # silently ignored on every kernel this host has ever run. dmesg on the
      # working 6.19 kernel proves it, reporting the opposite of what was asked:
      #   iommu: Default domain type: Translated
      # and the display controller then faults immediately at SMMU init.
      #
      # `iommu.passthrough=1` is the real spelling and actually takes effect.
      "iommu.passthrough=1"
      # NOTE: iteration 4 tried "arm-smmu-v3.disable_bypass=0" here on the theory
      # that NVMe was faulting behind the SMMU. It made no difference — no boot
      # markers, identical failure — so the hypothesis is rejected and the param
      # is removed rather than left to accumulate. Note it would have been a weak
      # test anyway: with domains still Translated, bypass was never in play.
      # Disable deep CPU idle states to prevent register corruption
      "cpuidle.off=1"
      # NOTE: SMMU bypass removed — testing with CIX's default SMMU config.
      # BIOS 1.2.1 may have fixed the IORT table. Re-add if NVMe crashes:
      #   "arm-smmu-v3.disable_bypass=0"
      # and add to kernel.nix: ./scripts/config --disable ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT
      # NOTE: module_blacklist=sbsa_gwdt removed — sbsa_gwdt is built-in (not a module)
      # so blacklisting it has no effect. nowatchdog handles watchdog suppression instead.
      # NOTE: `pstore_blk.blkdev=/dev/disk/by-partlabel/disk-main-pstore` removed.
      # It was a no-op: pstore supports exactly one backend and CONFIG_PSTORE_RAM
      # (ramoops, backed by the cix_ramoops@83d00000 reserved-memory node in the
      # Crash capture is configured via boot.kernel.sysctl below, not here.
      #
      # `panic_on_oops=1` was removed: it is not a kernel command line parameter,
      # and 7.2 says so explicitly —
      #   "Unknown kernel command line parameters "panic_on_oops=1", will be
      #    passed to user space."
      # It is a sysctl, exactly like iommu.default_domain_type turned out to be.
      #
      # `panic_print=0` was removed too: 7.2 deprecates it —
      #   "The 'panic_print' parameter is now deprecated. Please use
      #    'panic_sys_info' and 'panic_console_replay' instead."
      # and the sysctl overrode it regardless.
      #
      # On mainline there is no cix_ramoops DT node, so efi_pstore wins the
      # pstore backend slot and panics land in UEFI NVRAM, which survives both
      # reboot and power loss. That is the first reliable crash capture this
      # board has had — see the sysctl block for why it must stay small.
    ];

    # 5GbE and network performance tuning
    kernel.sysctl = {
      # 5GbE and network performance tuning
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.core.rmem_default" = 1048576;
      "net.core.wmem_default" = 1048576;
      "net.ipv4.tcp_rmem" = "4096 1048576 16777216";
      "net.ipv4.tcp_wmem" = "4096 1048576 16777216";
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Crash capture.
      #
      # These sysctls OVERRIDE the equivalent kernel command line parameters,
      # which is why panic=0 and panic_print=0 on the cmdline had no effect: the
      # box still rebooted (kernel.panic = 30) and still produced the all-tasks
      # flood (kernel.panic_print = 2047).
      #
      # That flood destroys the evidence twice over. It pushes the panic banner
      # and call trace off the top of the display, and it overflows the
      # efi_pstore records — a 7.2 panic filled all 20 EFI dump variables with
      # nothing but sched-debug and Mem-Info, with the actual reason long gone.
      #
      # panic_print = 0 stays: it keeps the banner and backtrace as the last
      # thing printed and small enough to fit in pstore. That is what let the
      # cdns_role_stop NULL deref be read back in full.
      #
      # panic = 0 (halt), NOT 30 (auto-reboot).
      #
      # 30 was set so the box would recover itself from a runtime crash. It
      # does the opposite for a crash during boot: the machine panics, reboots
      # into the same default generation, panics again, forever. That is
      # exactly what happened when iwlwifi was unblacklisted -- an infinite
      # loop that had to be broken by hand at the boot menu.
      #
      # Halting is the safer default here. Every failure on this board so far
      # has been at boot rather than at runtime, and a halted machine can be
      # pointed at another generation; a looping one cannot.
      "kernel.panic_on_oops" = 1; # turn an oops into a captured panic
      "kernel.panic" = 0;
      "kernel.panic_print" = 0;
    };

    # Modern boot management
    loader = {
      systemd-boot = {
        enable = true;

        # Disabled temporarily due to upstream edk2 build failure
        # extraFiles = {
        #   "efi/shell.efi" = "${pkgs.edk2-uefi-shell}/shell.efi";
        # };

        # extraEntries = {
        #   "update-bios.conf" = ''
        #     title Update Radxa BIOS
        #     efi /efi/shell.efi
        #     options -delay 0 \radxa-firmware\update-bios.nsh
        #     sort-key z_update_bios
        #   '';
        # };
      };

      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = lib.mkForce "/boot";
      };
    };
  };
  # Boot-stage markers removed. They existed to tell "never reached stage 2"
  # apart from "reached multi-user then died", back when 7.2 booted to a black
  # screen with no console and no journal. The machine boots and the journal
  # persists, so they are just files nobody reads now.

  environment.systemPackages = [
    cix-noe-umd
    pkgs.tpm2-tools # TPM 2.0 userspace tools (future use — tpm2_getrandom, tpm2_getcap, etc.)
    (pkgs.writeShellScriptBin "update-orion-bios" ''
      set -euo pipefail

      # Safety check: Ensure we are running on the ORION host
      CURRENT_HOST=$(cat /etc/hostname 2>/dev/null || echo "UNKNOWN")
      if [ "$CURRENT_HOST" != "ORION" ] && [ "$CURRENT_HOST" != "installer-orion" ]; then
        echo "ERROR: This script is only intended to be run on the ORION host!"
        echo "Current host is: $CURRENT_HOST"
        exit 1
      fi

      # Safety check: Ensure architecture is aarch64
      if [ "$(uname -m)" != "aarch64" ]; then
        echo "ERROR: This script requires an aarch64 architecture!"
        exit 1
      fi

      # Safety check: Ensure network connectivity
      if ! ${pkgs.iputils}/bin/ping -c 1 -W 2 github.com >/dev/null 2>&1; then
        echo "ERROR: Cannot reach github.com. Please check your internet connection."
        exit 1
      fi

      BIOS_VERSION="${orionBiosVersion}"

      echo "Downloading Radxa Orion O6 BIOS ''${BIOS_VERSION}..."
      TMPDIR=$(mktemp -d)
      cd $TMPDIR
      ${pkgs.curl}/bin/curl -sL "https://github.com/radxa-pkg/edk2-cix/releases/download/''${BIOS_VERSION}/edk2-cix_''${BIOS_VERSION}_all.deb" -o edk2.deb

      echo "Extracting..."
      ${pkgs.dpkg}/bin/dpkg-deb -x edk2.deb extracted

      echo "Cleaning up old EFI flasher files..."
      sudo rm -rf /boot/radxa-firmware

      echo "Installing EFI flasher to /boot/radxa-firmware..."
      sudo mkdir -p /boot/radxa-firmware
      sudo cp -r extracted/usr/share/edk2/radxa/orion-o6/* /boot/radxa-firmware/

      echo "Generating interactive EFI update wrapper..."
      cat << 'EOF' | sudo tee /boot/radxa-firmware/update-bios.nsh >/dev/null
      @echo -off
      echo .
      echo =================================================
      echo "  Radxa Orion O6 BIOS Update"
      echo =================================================
      echo .
      echo WARNING: DO NOT TURN OFF POWER DURING THE UPDATE
      echo Press 'q' to abort, or any other key to proceed.
      echo .
      pause -q
      if %lasterror% neq 0 then
      goto do_abort
      endif

      if exist fs0:\radxa-firmware\startup.nsh then
      fs0:
      endif
      if exist fs1:\radxa-firmware\startup.nsh then
      fs1:
      endif
      if exist fs2:\radxa-firmware\startup.nsh then
      fs2:
      endif

      cd radxa-firmware
      startup.nsh
      goto done

      :do_abort
      echo "Update aborted by user."

      :done
      EOF
      echo "Done!"
      echo ""
      echo "To flash the BIOS:"
      echo "1. Reboot the machine."
      echo "2. Select 'Update Radxa BIOS' from the systemd-boot menu."
      echo "   (If it does not automatically launch, select the EFI Shell and run:"
      echo "    fs0: -> cd radxa-firmware -> update-bios.nsh)"

      rm -rf $TMPDIR
    '')
  ];

  hardware = {
    enableRedistributableFirmware = true;
    firmware = [
      sky1-firmware
      cix-dsp-firmware
    ];
    deviceTree = {
      enable = true;
      # Mainline's own board DTS. It enables all five PCIe root complexes
      # (&pcie_x8_rc through &pcie_x1_1_rc) and the uart2 console, which is
      # everything needed to reach an NVMe root filesystem.
      name = "cix/sky1-orion-o6.dtb";

      # NOTE: the "smmu-mmhub-bypass" overlay was removed. It targeted
      # /iommu@b1b0000, a node that only existed in the downstream DTS —
      # mainline's sky1.dtsi has no such node, so the overlay could not apply.
      # Early-boot DMA faults are handled by iommu.passthrough=1 on the cmdline
      # instead. Re-introduce a mainline-compatible overlay here if a real SMMU
      # stream-ID problem shows up.
      overlays = [ ];
    };
  };

  services.udev.extraRules = ''
    KERNEL=="aipu", MODE="0660", GROUP="render"

    # Disable runtime suspend for Cadence USB controllers to prevent IRQ storm/hang when Type-C mode switches
    SUBSYSTEM=="platform", DRIVERS=="cdnsp-sky1", ATTR{power/control}="on"
    SUBSYSTEM=="platform", DRIVERS=="cdns-usbssp", ATTR{power/control}="on"

    # Note: Disable USB 3.0 Bus 14 root hub to prevent log spam/training loop.
    # This is handled via boot.postBootCommands (unbind usb14) in hosts/orion/default.nix
    # because the udev disable attribute is missing on this kernel.
  '';

  # AIPULIB_PATH: scoped to interactive sessions only
  # NPU applications are launched via nix-shell; global LD_LIBRARY_PATH breaks system tools
  environment.sessionVariables = {
    AIPULIB_PATH = "${cix-noe-umd}/lib";
  };

  # Wi-Fi is off on this host and Bluetooth does not need it.
  #
  # The AX210 is a combo card but its two halves are independent devices on
  # different buses: Bluetooth is USB (btusb, internal bus 3), Wi-Fi is PCIe
  # (iwlwifi, 0001:61:00.0). Blacklisting iwlwifi leaves Bluetooth completely
  # untouched -- hci0 pairs and discovers with the blacklist in place.
  #
  # Expected noise, do not chase: the Bluetooth firmware download always fails
  # on its first attempt and always succeeds on the retry.
  #   Bluetooth: hci0: Failed to send firmware data (-19)
  #   Bluetooth: hci0: FW download error recovery failed (-108)
  #   ...device re-enumerates, btusb retries...
  #   Bluetooth: hci0: Firmware loaded in 1342165 usecs
  #   Bluetooth: hci0: Fseq status: Success (0x00)
  # hci0 therefore runs the full patched firmware (build 82122), not the
  # bootloader fallback. The -19 is ENODEV from the card dropping off the bus
  # as it switches out of bootloader mode, which is an Intel quirk and not a
  # fault in our cdnsp USB work: every prior boot shows the identical
  # fail-then-succeed pair, and there are zero other USB errors across the 24
  # enumerated devices. Costs roughly 1.3s of boot time and nothing else.
  #
  # Wi-Fi stays off because iwl_pci_probe panics the machine:
  #   iwlwifi 0001:61:00.0: Unable to change power state from D3cold to D0,
  #                         device inaccessible
  #   SError Interrupt on CPU11 -- Kernel panic
  # The card sits in D3cold and nothing brings it out. vdd_3v3_wlan supplies
  # the rail (which is what got Bluetooth working) but mainline's pci-sky1.c
  # has no PCIe power-state handling, so the PCIe function stays inaccessible.
  #
  # Wi-Fi is abandoned on this host, so no wireless stack runs at all. The
  # shared system/config/network/wireless module is simply not imported in
  # this host's default.nix, which is cleaner than importing it and then
  # fighting it. These stay as belt-and-braces so an import added elsewhere
  # cannot quietly start a supplicant on a box with no Wi-Fi device.
  #
  # NetworkManager is deliberately left enabled: it manages the wired link
  # (enP3p1s0). Only the wireless daemons are suppressed.
  #
  # Revisit if D3cold->D0 handling is ever added to the PCIe driver.
  networking = {
    wireless.enable = lib.mkForce false; # wpa_supplicant
    wireless.iwd.enable = lib.mkForce false; # iwd / iwctl

    # Use systemd-networkd for Ethernet management
    useNetworkd = true;
    useDHCP = lib.mkForce false;
  };
  systemd = {
    network.wait-online.anyInterface = true;

    network.networks."10-lan" = {
      matchConfig.Name = [
        "en*"
        "eth*"
      ];
      networkConfig.DHCP = "yes";
    };

    # CIX P1 hides its Cortex-A720 turbo operating points behind the cpufreq
    # boost control, which defaults to off. Without this the machine runs a long
    # way below spec:
    #
    #                       boost=0     boost=1
    #   policy0  A720 big    1.50 GHz -> 2.60 GHz
    #   policy9  A720 big    1.50 GHz -> 2.50 GHz
    #   policy5  A720 mid    1.50 GHz -> 2.30 GHz
    #   policy7  A720 mid    1.50 GHz -> 2.20 GHz
    #   policy1  A520 little 1.80 GHz    1.80 GHz  (already correct)
    #
    # The perf-domain wiring itself is fine — mainline's sky1.dtsi maps each CPU
    # to the right SCMI domain (SKY1_PERF_CPU_L=2, B0=3, B1=4, M0=5, M1=6),
    # which matches the downstream DTS exactly. Only the boost gate was missing.
    services.cpufreq-boost = {
      description = "Enable cpufreq boost (unlocks Cortex-A720 turbo OPPs)";
      wantedBy = [ "multi-user.target" ];
      after = [ "sysinit.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        b=/sys/devices/system/cpu/cpufreq/boost
        if [ -e "$b" ]; then
          echo 1 > "$b"
          echo "cpufreq boost enabled: $(cat $b)"
        else
          echo "no cpufreq boost control present; nothing to do"
        fi
      '';
    };

  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
