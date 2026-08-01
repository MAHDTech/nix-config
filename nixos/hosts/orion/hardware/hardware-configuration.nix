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
    blacklistedKernelModules = [
      "panfrost"
      "iwlwifi"
    ];

    # ── TEMPORARY: v7.2 boot diagnostics ──────────────────────────────────
    # The 7.2.0-rc5 generation hangs with a completely black screen after the
    # systemd-boot menu — no panic (it sat >4 min with panic=30 set, so it
    # never oopsed), no journal, no pstore record.
    #
    # Nothing was captured because all three capture paths are inert:
    #   1. `quiet` (from soe/boot, consoleLogLevel = 4) suppresses early printk
    #   2. no earlycon, so nothing prints before the PL011 driver probes
    #   3. pstore_blk never registers — CONFIG_PSTORE_RAM wins the single
    #      backend slot (dmesg: "Registered ramoops as persistent store
    #      backend"), so the 16M disk-main-pstore partition is never written
    #
    # Remove this block, and restore `nowatchdog`, once 7.2 boots.
    consoleLogLevel = lib.mkForce 7; # drops `quiet` from the cmdline
    plymouth.enable = lib.mkForce false; # drops `splash`; stops plymouth hiding the console

    kernelParams = [
      # ── diagnostics (temporary — see note above) ──
      # efifb earlycon writes straight to the EFI GOP framebuffer, so early
      # boot messages appear on the monitor with no serial cable attached.
      # CONFIG_EFI_EARLYCON=y is verified by the kernel validation gate.
      "earlycon=efifb"
      "keep_bootcon" # don't drop earlycon when the real console takes over
      "ignore_loglevel" # print everything regardless of loglevel
      # NOTE: `initcall_debug` removed. It emitted thousands of lines to the
      # EFI framebuffer, which has no acceleration — every scroll copies the
      # whole buffer. That made the log unreadable and the boot glacial without
      # telling us where it dies. The on-disk boot markers below answer that.
      # ── end diagnostics ──

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
      # NOTE: `nowatchdog` temporarily removed. Despite the old comment it does
      # NOT suppress platform watchdogs — it disables the kernel soft/hard
      # lockup detectors, which is precisely what would print a stack trace for
      # a silent hang like this one. Restore it once 7.2 boots.
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
      # panic_print = 0 keeps the banner and backtrace as the last thing printed
      # and small enough to fit in pstore. panic = 0 halts instead of rebooting,
      # so the screen can also be read. Restore both once 7.2 boots.
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

  # ── TEMPORARY: v7.2 boot-stage markers ────────────────────────────────────
  # ORION has NO working persistent crash capture:
  #   - pstore_blk never registers (CONFIG_PSTORE_RAM holds the single backend slot)
  #   - ramoops registers fine but does NOT survive a reboot — a pmsg marker
  #     written to /dev/pmsg0 was gone after a clean software reboot, so the
  #     firmware scrubs DRAM on every boot
  # and the EFI framebuffer console scrolls far too fast to photograph.
  #
  # These markers record how far a boot got, straight onto the root filesystem.
  # They survive DRAM loss, need no screen, and need no network — so after a
  # rescue into the last known-good generation we can read exactly which stage
  # the 7.2 kernel reached. Each records the kernel version, so a stale marker
  # from a previous boot can never be mistaken for a fresh one.
  #
  # Remove this block once 7.2 boots.
  boot.initrd.systemd.services.orion-boot-marker = {
    description = "ORION: record that initrd mounted the root filesystem";
    wantedBy = [ "initrd.target" ];
    after = [ "sysroot.mount" ];
    before = [ "initrd-switch-root.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /sysroot/var/lib/orion-boot-markers
      echo "stage=initrd-root-mounted kernel=$(uname -r) uptime=$(cut -d' ' -f1 /proc/uptime)" \
        > /sysroot/var/lib/orion-boot-markers/01-initrd
    '';
  };

  boot.postBootCommands = ''
    mkdir -p /var/lib/orion-boot-markers
    echo "stage=stage2-early kernel=$(uname -r) uptime=$(cut -d' ' -f1 /proc/uptime)" \
      > /var/lib/orion-boot-markers/02-stage2-early
  '';

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

  # Use systemd-networkd for Ethernet management
  networking.useNetworkd = true;
  networking.useDHCP = lib.mkForce false;
  systemd = {
    network.wait-online.anyInterface = true;

    network.networks."10-lan" = {
      matchConfig.Name = [
        "en*"
        "eth*"
      ];
      networkConfig.DHCP = "yes";
    };

    # TEMPORARY (v7.2 debug): third boot-stage marker — see the marker block above.
    # Captures interface and address state too, so a boot that succeeds but comes
    # up with no NIC is distinguishable from one that never got here at all.
    services.orion-boot-marker-late = {
      description = "ORION: record that the boot reached multi-user";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-networkd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /var/lib/orion-boot-markers
        {
          echo "stage=multi-user kernel=$(uname -r) uptime=$(cut -d' ' -f1 /proc/uptime)"
          echo "--- interfaces ---"
          ${pkgs.iproute2}/bin/ip -o link || true
          echo "--- addresses ---"
          ${pkgs.iproute2}/bin/ip -o addr || true
        } > /var/lib/orion-boot-markers/03-multi-user
      '';
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
