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
    # In installer mode, only load display essentials. Skip NPU, VPU, KVM,
    # Type-C, and cpufreq — they're unnecessary for SSH-based installs.
    kernelModules = [
      # Display pipeline — always loaded (user needs screen output)
      "panthor" # Immortalis-G720 MC10 GPU (CSF-based)
      "linlon-dp" # CIX Display controller
      "trilin-dpsub" # CIX DisplayPort subsystem

      # USB-C Power Delivery and DisplayPort Alt Mode (Required for pure DT boot)
      "typec"
      "typec_ucsi"
      "typec_displayport"
    ]
    ++ lib.optionals (!isInstaller) [
      "kvm"
      "aipu" # CIX NPU
      "amvx" # CIX VPU
    ];

    # Prevent panfrost from loading (wrong driver for Immortalis-G720 CSF, use panthor)
    # Belt-and-suspenders: also add via module_blacklist= kernel param below
    blacklistedKernelModules = [ "panfrost" ];

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

      "console=ttyAMA0,115200n8"
      "console=tty0"
      "fbcon=map:1" # Map the system console to the native display framebuffer (fb1) rather than simpledrm (fb0)
      "acpi=off" # Force Device Tree by completely ignoring the EDK2 BIOS ACPI tables
      # NOTE: `nowatchdog` temporarily removed. Despite the old comment it does
      # NOT suppress platform watchdogs — it disables the kernel soft/hard
      # lockup detectors, which is precisely what would print a stack trace for
      # a silent hang like this one. Restore it once 7.2 boots.
      # Belt-and-suspenders panfrost blacklist via kernel param (NixOS option alone not sufficient)
      "module_blacklist=panfrost"
      # clk_ignore_unused: prevent kernel from disabling clocks before drivers initialise
      # Required on CIX P1 to avoid slow boot and hardware init races
      "clk_ignore_unused"
      # Configure global SMMU to use passthrough mappings (bypass) by default to prevent early-boot display DMA faults
      "iommu.default_domain_type=passthrough"
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
      # Sky1 DTS) always registers first. The 16M partition was never written to.
      # Ramoops is the better backend here anyway — it needs no drivers, so it can
      # capture failures that happen long before NVMe is up.
      "panic_on_oops=1"
      # TEMPORARY (v7.2 debug): panic=0 so the machine freezes on the panic
      # screen instead of rebooting, and panic_print=0 so the panic banner and
      # backtrace are the LAST thing on screen rather than being scrolled away.
      #
      # panic() prints the banner and dump_stack() FIRST, then panic_print_sys_info()
      # dumps all tasks, memory, timers, locks and replays the whole printk ring.
      # With panic_print=0x7ff that flood pushed the actual panic reason off the
      # top of the display — observed as "scrolling white text too fast to read".
      #
      # Restore `panic=30` and `panic_print=0x7ff` once 7.2 boots.
      "panic=0"
      "panic_print=0"
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
      # Crash capture: ensure panic settings survive into running system
      "kernel.panic_on_oops" = 1;
      "kernel.panic" = 30;
      "kernel.panic_print" = 2047; # 0x7ff — all info
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
      name = "cix/sky1-orion-o6.dtb";
      overlays = [
        {
          name = "smmu-mmhub-bypass";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "cix,sky1";
              fragment@0 {
                target-path = "/iommu@b1b0000";
                __overlay__ {
                  arm,boot-active-sids = <
                    0x00 0x01 0x03 0x04 0x05
                    0x06 0x07 0x09 0x0a 0x0b
                    0x0c 0x0d 0x0f 0x10 0x11
                    0x12 0x13 0x15 0x16 0x17
                    0x18 0x19 0x1b 0x1c 0x1d
                  >;
                };
              };
            };
          '';
        }
      ];
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
