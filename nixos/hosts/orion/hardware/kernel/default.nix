{
  pkgs,
  lib,
  ...
}:

let
  modDirVersion = "7.2.0-rc5";

  # Fetch Sky1-Linux patches repository for the kernel config
  # Pinned to specific commit SHA for reproducibility
  sky1Patches = pkgs.fetchFromGitHub {
    owner = "Sky1-Linux";
    repo = "linux-sky1";
    rev = "57e018a398248d7e5e4d798610df79a557c0629f";
    hash = "sha256-cPQdu9pTNsn3gAcX5kr8VxxLMorD8FQoDFu7t63Zo2A=";
  };

  # Build the custom patched v7.2-rc5 kernel
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "linux-cix-mainline";
    version = modDirVersion;

    src = pkgs.fetchurl {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-7.2-rc5.tar.gz";
      sha256 = "07nm1mdpx9nqxh8bin0isnl2b7460if5g7ssy4krkj2vbhjbzrcb";
    };

    nativeBuildInputs = with pkgs; [
      bc
      bison
      elfutils
      flex
      gmp
      gnumake
      kmod
      libmpc
      mpfr
      nettools
      openssl
      perl
      python3
      rsync
      util-linux
      zlib
      zstd
    ];

    buildInputs = with pkgs; [
      zlib
      elfutils
    ];

    # Enable Armv8 Cryptography Extensions (AES/NEON) to fix crypto/aegis128-neon-inner assembler failures
    NIX_CFLAGS_COMPILE = "-march=armv8-a+crypto";

    # Apply per-subsystem Sky1-Linux patches for 7.2-rc5
    # Split from the original consolidated patch for:
    #   - Isolation: each subsystem patch can be tested/disabled independently
    #   - Debugging: build errors point directly to the responsible patch
    #   - Maintenance: each patch can be rebased independently per kernel bump
    #
    # Note: pcie-cadence-host.c is NOT patched — the upstream 7.2-rc5 HPA driver
    # path (pcie-cadence-host-hpa.c) already provides ECAM support via
    # cdns_pcie_hpa_create_region_for_cfg() and rc->ecam_supported.
    #
    # Realtek r8125/r8126 out-of-tree drivers are dropped — using in-kernel r8169
    # which added RTL8126 support in the 7.x cycle (PCI ID 10ec:8126, firmware
    # rtl8126a-{2,3}.fw).
    prePatch = ''
      echo "Applying Sky1-Linux per-subsystem patches for 7.2-rc5..."
      for p in \
        ${./patches/01-devicetree.patch} \
        ${./patches/02-pcie-cadence.patch} \
        ${./patches/03-infra-scmi-clk-reset.patch} \
        ${./patches/04-usb-phy-typec.patch} \
        ${./patches/05-display-drm-cix.patch} \
        ${./patches/06-gpu-panthor.patch} \
        ${./patches/07-audio-asoc.patch} \
        ${./patches/08-npu-armchina.patch} \
        ${./patches/09-vpu-linlon.patch} \
        ${./patches/10-irq-iommu-smmu.patch} \
        ${./patches/11-misc-thermal-pwm.patch} \
        ${./patches/12-soc-firmware-dsp.patch} \
      ; do
        echo "  Applying $(basename $p)..."
        patch -p1 --fuzz=0 < "$p"
      done
      echo "All 12 subsystem patches applied successfully."

      # ── Guard: mailbox DT binding must match the upstreamed driver ──────────
      # 7.2 carries drivers/mailbox/cix-mailbox.c in mainline, and it reads the
      # direction as a STRING named "cix,mbox-dir":
      #     device_property_read_string(dev, "cix,mbox-dir", &dir_str)
      #     "tx" -> dir 0, "rx" -> dir 1, anything else -> -EINVAL
      #
      # The downstream DTS used a u32 "cix,mbox_dir = <0>" instead. With the
      # compatible string still matching, the driver bound and then failed probe
      # with -EINVAL, so 6590000.mailbox never registered. Everything hangs off
      # that: firmware:scmi could not probe ("supplier 6590000.mailbox not
      # ready"), so SCMI clocks never appeared, so pcie_phy and then pcie
      # deferred forever, so NVMe never enumerated and the initrd timed out
      # waiting for the root device.
      #
      # Fail the build if the stale spelling ever comes back.
      if grep -rn "cix,mbox_dir" arch/arm64/boot/dts/cix/ 2>/dev/null; then
        echo "FATAL: DTS uses the stale 'cix,mbox_dir' u32 property." >&2
        echo "Mainline cix-mailbox.c requires 'cix,mbox-dir' as a string (tx/rx)." >&2
        echo "Mailbox probe would fail -EINVAL and the root device would never appear." >&2
        exit 1
      fi
      if ! grep -rq 'cix,mbox-dir = "tx"' arch/arm64/boot/dts/cix/ 2>/dev/null; then
        echo "FATAL: no 'cix,mbox-dir = \"tx\"' found in the Sky1 DTS." >&2
        exit 1
      fi
      echo "Mailbox DT binding verified against the mainline driver."

      # ── Guard: reset controller DT binding ──────────────────────────────────
      # Same class of bug as the mailbox. 7.2 carries drivers/reset/reset-sky1.c
      # in mainline, matching only:
      #   { "cix,sky1-system-control",    &variant_sky1_fch }  @ 0x04160000
      #   { "cix,sky1-s5-system-control", &variant_sky1     }  @ 0x16000000
      # The downstream DTS used "cix,sky1-src" / "cix,sky1-src-fch", so nothing
      # bound, no reset controller registered, and every consumer deferred with
      # -517 forever: pcie, usb, gpio, pwm — and therefore no root device.
      if grep -rn 'cix,sky1-src' arch/arm64/boot/dts/cix/ 2>/dev/null; then
        echo "FATAL: DTS uses stale 'cix,sky1-src*' reset compatibles." >&2
        echo "Mainline reset-sky1.c only matches cix,sky1-system-control and" >&2
        echo "cix,sky1-s5-system-control. Nothing would bind and every device" >&2
        echo "needing a reset would defer with -EPROBE_DEFER forever." >&2
        exit 1
      fi
      for c in "cix,sky1-system-control" "cix,sky1-s5-system-control"; do
        if ! grep -rq "$c" arch/arm64/boot/dts/cix/ 2>/dev/null; then
          echo "FATAL: DTS is missing reset compatible '$c'." >&2
          exit 1
        fi
      done
      echo "Reset controller DT binding verified against the mainline driver."
    '';

    configurePhase = ''
      patchShebangs scripts
      patchShebangs tools

      # ── Phase 1: Load Sky1's official config ────────────────────────────────
      # Use Sky1-Linux's tested configuration for the Orion O6 / Sky1 SoC.
      # The -next config targets mainline/origin-master which is closest to 7.2.
      cp ${sky1Patches}/config/config.sky1-next .config

      # Single olddefconfig pass: resolve the full Kconfig dependency tree.
      make ARCH=arm64 olddefconfig

      # ── Phase 2: NixOS-specific overrides ───────────────────────────────────
      # IMPORTANT: All ./scripts/config calls MUST go AFTER olddefconfig.
      # Only options that differ from CIX's defconfig or are NixOS-specific
      # need to be set here.

      # --- Fallback display (not in CIX defconfig) ---
      ./scripts/config --enable DRM_SIMPLEDRM

      # --- Display pipeline extras (not in CIX defconfig, may be auto-selected) ---
      ./scripts/config --enable DRM_LINLONDP_CLOCK_FIXED
      ./scripts/config --module DRM_TRILIN_CADENCE_PHY

      # --- Strict devmem for kernel security (not in CIX defconfig) ---
      ./scripts/config --enable STRICT_DEVMEM

      # --- NVMe: force built-in for robust early-boot root mount ---
      # CIX defconfig has NVMe as module; NixOS needs built-in for root on NVMe
      ./scripts/config --enable BLK_DEV_NVME

      # --- Persistent crash capture via block device (pstore-blk) ---
      # Captures panic/oops/console logs to a dedicated 16M raw partition
      # Survives reboot and power loss (unlike ramoops which needs reserved RAM)
      ./scripts/config --enable PSTORE
      ./scripts/config --enable PSTORE_BLK
      ./scripts/config --enable PSTORE_CONSOLE
      ./scripts/config --enable PSTORE_PMSG
      ./scripts/config --enable PSTORE_RAM

      # --- zram: compressed RAM swap (required by NixOS zramSwap module) ---
      ./scripts/config --module ZRAM
      ./scripts/config --enable ZRAM_DEF_COMP_ZSTD
      ./scripts/config --enable LRU_GEN
      ./scripts/config --enable LRU_GEN_ENABLED
      ./scripts/config --enable ZRAM_BACKEND_ZSTD

      # --- AppArmor: mandatory access control ---
      # Required by security.apparmor.enable = true in the SOE security config
      ./scripts/config --enable SECURITY_APPARMOR
      ./scripts/config --enable DEFAULT_SECURITY_APPARMOR

      # --- NixOS boot requirements (not in CIX defconfig) ---
      ./scripts/config --enable DEVTMPFS_MOUNT
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable SECCOMP
      ./scripts/config --module TCG_TIS
      ./scripts/config --module TCG_CRB
      ./scripts/config --module USB_UHCI_HCD

      # --- NixOS Firewall/Netfilter requirements ---
      ./scripts/config --module NETFILTER_XT_MATCH_PKTTYPE
      ./scripts/config --module NETFILTER_XT_MATCH_IPRANGE
      ./scripts/config --module IP_NF_MATCH_RPFILTER
      ./scripts/config --module IP6_NF_MATCH_RPFILTER

      # --- Firmware compression support (NixOS compresses firmware with ZSTD) ---
      ./scripts/config --enable FW_LOADER_COMPRESS
      ./scripts/config --enable FW_LOADER_COMPRESS_ZSTD

      # --- BTRFS crypto dependencies (not in CIX defconfig) ---
      # NixOS uses BTRFS with crc32c checksums; blake2b and xxhash are also
      # required as loadable modules for the initrd to mount the root filesystem.
      ./scripts/config --module CRYPTO_BLAKE2B
      ./scripts/config --module CRYPTO_CRC32C
      ./scripts/config --module CRYPTO_XXHASH

      # --- NixOS filesystem codepage support (not in CIX defconfig) ---
      ./scripts/config --module NLS_CP437
      ./scripts/config --module NLS_UTF8

      # --- Realtek r8169 NIC driver (replaces out-of-tree r8125/r8126) ---
      # Upstream r8169 in 7.2-rc5 has full RTL8126 support (PCI ID 10ec:8126)
      # with dedicated rtl_hw_start_8126a init and firmware loading.
      # Sky1's config enables the out-of-tree r8125/r8126 — disable them since
      # the driver source was dropped from the patches.
      ./scripts/config --module R8169
      ./scripts/config --disable R8125
      ./scripts/config --disable R8126

      # --- USB Ethernet drivers (specific adapters not in CIX defconfig) ---
      ./scripts/config --module USB_NET_AX88179_178A
      ./scripts/config --module USB_NET_CDCETHER
      ./scripts/config --module USB_NET_CDC_NCM

      # --- Disable debug symbols to reduce build size and compile time ---
      # CIX defconfig enables BTF and DWARF5; disable to save ~500MB build output
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --disable DEBUG_INFO_BTF
      ./scripts/config --disable DEBUG_INFO_DWARF5
      ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT

      # --- Disable the CIX audio subsystem (AUDSS) ---
      # clk-sky1-audss panics the kernel during boot:
      #
      #   sky1_audss_clk_probe+0x4c0/0xaf0
      #     __pm_runtime_idle -> rpm_suspend -> genpd_runtime_suspend
      #       sky1_audss_clk_runtime_suspend+0x44/0xb0
      #         regmap_read -> regmap_mmio_read32le -> el1h_64_error
      #   Kernel panic - not syncing: Asynchronous SError Interrupt
      #
      # The driver takes pm_runtime_get_noresume() in probe and comments that
      # "the initial reference is kept", but its clock-gate op calls
      # pm_runtime_put(). Partway through clock registration the count hits zero,
      # runtime PM suspends the device, and runtime_suspend reads MMIO on a block
      # whose clock and power are already gated — which SErrors on this SoC.
      #
      # AUDSS is not needed to boot, and this driver is still an out-of-tree v10
      # patchset upstream (see scratch/orion-kernel-report.md). Disable the clock
      # and reset halves together — they drive the same block, and the reset
      # driver also does a bare regmap_read against it.
      #
      # Cost: no I2S audio or DSP until the get/put imbalance is fixed properly.
      ./scripts/config --disable CLK_SKY1_AUDSS
      ./scripts/config --disable RESET_SKY1_AUDSS

      # --- Disable irrelevant PCIe GPU drivers (CIX defconfig enables these) ---
      ./scripts/config --disable DRM_AMDGPU
      ./scripts/config --disable DRM_NOUVEAU
      ./scripts/config --disable DRM_RADEON

      # --- Disable irrelevant SoC architectures to optimize compile time ---
      ./scripts/config --disable ARCH_QCOM
      ./scripts/config --disable ARCH_TEGRA
      ./scripts/config --disable ARCH_ROCKCHIP

      # --- Disable built-in extra firmware ---
      # CIX defconfig includes extra firmware (e.g. rtw89 binaries) built-in.
      # This fails in the NixOS isolated build sandbox which has no /lib/firmware.
      ./scripts/config --set-str EXTRA_FIRMWARE ""

      # Run olddefconfig again to resolve all new config overrides and dependencies non-interactively
      make ARCH=arm64 olddefconfig

      # ── Phase 3: Validation gate ─────────────────────────────────────────
      # Verify critical CIX and NixOS options survived configuration.
      # If any are missing, the build fails immediately rather than
      # producing a kernel with silently disabled drivers.
      # The list below covers three groups:
      #   1. Peripherals — the original CIX display/PHY/DSP/Type-C set.
      #   2. Boot path — everything needed to reach a shell. Previously
      #      unguarded, so a silently-dropped symbol produced an unbootable
      #      kernel that still built cleanly.
      #   3. Observability — without these, a failed boot is a black screen.
      #
      # NOTE on USB symbol names: 7.2 merged the CDNSP driver into cdns3.
      # USB_CDNS_HOST, USB_CDNSP_HOST and USB_CDNSP_GADGET no longer exist
      # upstream — USB_CDNS3_HOST and USB_CDNS3_GADGET are their replacements
      # and now cover both the USBSS and USBSSP IP. Do not re-add the old names.
      echo "Validating kernel configuration..."
      MISSING=0
      for opt in \
        DRM_CIX DRM_LINLONDP DRM_TRILIN_DPSUB DRM_TRILIN_DP_CIX \
        DRM_CIX_EDP_PANEL DRM_PANTHOR \
        PHY_CIX_USBDP PWM_SKY1 CIX_DSP \
        USB_CDNSP TYPEC TYPEC_RTS5453 \
        BLK_DEV_NVME PSTORE PSTORE_BLK \
        ARCH_CIX OF_FLATTREE EFI_STUB \
        PCI_SKY1 PCI_ECAM PCIE_CADENCE_HOST \
        BTRFS_FS RD_ZSTD \
        MAILBOX CIX_MBOX ARM_SCMI_PROTOCOL ARM_SCMI_TRANSPORT_MAILBOX COMMON_CLK_SCMI \
        SERIAL_AMBA_PL011_CONSOLE EFI_EARLYCON \
        USB_CDNS3_HOST USB_CDNS3_GADGET USB_CDNSP_SKY1; do
        if ! grep -q "CONFIG_''${opt}=[ym]" .config; then
          echo "FATAL: CONFIG_''${opt} is not enabled in .config!" >&2
          MISSING=$((MISSING + 1))
        fi
      done
      if [ "$MISSING" -gt 0 ]; then
        echo "" >&2
        echo "ERROR: $MISSING required kernel config option(s) are missing." >&2
        echo "This likely means a Kconfig 'depends on' prerequisite is unmet." >&2
        echo "Check the Kconfig files in the patched source for dependency chains." >&2
        exit 1
      fi
      echo "All critical kernel config options verified."
    '';

    buildPhase = ''
      # Compile the kernel image, device tree blobs, and modules
      make ARCH=arm64 -j$NIX_BUILD_CORES Image
      make ARCH=arm64 -j$NIX_BUILD_CORES dtbs
      make ARCH=arm64 -j$NIX_BUILD_CORES modules
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp .config $out/config

      # Copy DTBs
      mkdir -p $out/boot/dts/cix
      cp arch/arm64/boot/dts/cix/*.dtb $out/boot/dts/cix/
      mkdir -p $out/dtbs/cix
      cp arch/arm64/boot/dts/cix/*.dtb $out/dtbs/cix/

      # Install kernel modules
      make ARCH=arm64 INSTALL_MOD_PATH=$out modules_install

      # Populate build directory for out-of-tree kernel modules (instead of deleting it)
      rm -f $out/lib/modules/*/build
      rm -f $out/lib/modules/*/source

      mkdir -p $out/lib/modules/${modDirVersion}/build
      cp Makefile Kbuild .config Module.symvers System.map $out/lib/modules/${modDirVersion}/build/

      cp -r include $out/lib/modules/${modDirVersion}/build/
      mkdir -p $out/lib/modules/${modDirVersion}/build/arch/arm64
      cp -r arch/arm64/include $out/lib/modules/${modDirVersion}/build/arch/arm64/
      cp arch/arm64/Makefile $out/lib/modules/${modDirVersion}/build/arch/arm64/

      # Copy scripts and tools which contain host-compiled binaries needed by make modules
      cp -r scripts $out/lib/modules/${modDirVersion}/build/
      cp -r tools $out/lib/modules/${modDirVersion}/build/

      # Clean up intermediate .o and .cmd files in build/scripts and build/tools to save space
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.cmd" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.cmd" -exec rm -f {} +

      # Remove dangling symlinks from the kernel build tree.
      # The kernel source has symlinks in two places that point to dirs we don't copy:
      #   - scripts/dtc/include-prefixes/{arm,mips,powerpc,riscv,...} -> arch/*/boot/dts
      #     (we only ship arch/arm64; other arch DTS dirs are irrelevant for this build)
      #   - tools/testing/selftests/{bpf,vfio,powerpc,...} -> kernel/bpf/, drivers/dma/, arch/powerpc/
      #     (kernel self-tests are not needed for out-of-tree NPU/VPU module builds)
      # Nix's fixupPhase noBrokenSymlinks check will fail on these, so remove them now.
      find $out/lib/modules/${modDirVersion}/build -xtype l -delete
    '';

    # Satisfy kernel modules and build expectations (e.g. for NPU/VPU drivers)
    passthru = rec {
      modDirVersion = "7.2.0-rc5";
      version = modDirVersion;
      dev = kernelBuild;
      moduleBuildDependencies = [ ];
      configfile = "${kernelBuild}/config";
      config = {
        isEnabled = _: true;
        isYes = _: true;
        isNo = _: false;
        isModule = _: false;
        isSet = _: true;
      };
      kernelOlder = v: lib.versionOlder version v;
      kernelAtLeast = v: lib.versionAtLeast version v;
      features = {
        efiBootStub = true;
      };
      commonMakeFlags = [ "ARCH=arm64" ];
    };
  };
in
kernelBuild
