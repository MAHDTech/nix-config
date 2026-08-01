{
  pkgs,
  lib,
  ...
}:
# ─────────────────────────────────────────────────────────────────────────────
# ORION kernel — MAINLINE FIRST
#
# Policy: if it is in mainline we use mainline's version. If it is not, we carry
# our own additive patch. We never overwrite code mainline already ships.
#
# That policy exists because the previous approach — vanilla 7.2-rc5 with the
# Sky1-Linux 6.x patch stack rebased on top — produced a run of failures that
# were all self-inflicted, each one the downstream patch bulldozing code that
# mainline already had correct:
#
#   * the DTS replaced mainline's `cix,mbox-dir = "tx"` (string) with the stale
#     `cix,mbox_dir = <0>` (u32). cix-mailbox.c probe returned -EINVAL, so SCMI
#     never came up, so no clocks, no PCIe, no NVMe, no root device.
#   * the DTS replaced mainline's `cix,sky1-system-control` reset compatibles
#     with the stale `cix,sky1-src`, so reset-sky1.c never bound and every
#     consumer deferred with -EPROBE_DEFER forever.
#   * the PCIe patch deleted mainline's PCI_SKY1_HOST and pci-sky1.c and
#     substituted the 6.x driver with hand-adapted 7.2 API calls, which then
#     oopsed on a wild write in sky1_pcie_really_probe.
#
# Mainline 7.2-rc5 already ships everything on the boot path:
#
#   arch/arm64/boot/dts/cix/sky1.dtsi           808 lines
#   arch/arm64/boot/dts/cix/sky1-orion-o6.dts   119 lines (enables all 5 PCIe RCs
#                                                          and the uart2 console)
#   drivers/mailbox/cix-mailbox.c               643 lines
#   drivers/reset/reset-sky1.c                  367 lines
#   drivers/pinctrl/cix/pinctrl-sky1.c          558 lines
#   drivers/pci/controller/cadence/pci-sky1.c   240 lines
#
# What mainline does NOT have, and what we therefore still need our own patches
# for, is the peripheral set: display (linlon-dp, trilin-dpsub), the Panthor
# SCMI/DVFS glue, USB-C PHY, audio, NPU, VPU, thermal and PWM.
#
# STAGE 1 (this file): no patches at all. Establish that a mainline kernel boots
# on this board with NVMe root and networking. Peripherals come back one at a
# time on top of a machine that already boots, so a broken peripheral costs that
# device rather than the whole system.
# ─────────────────────────────────────────────────────────────────────────────
let
  modDirVersion = "7.2.0-rc5";

  # Additive-only patches for subsystems mainline does not carry.
  # Empty for stage 1. Add entries here as each peripheral is rebased against
  # 7.2 and verified; every one must ADD files or DT nodes, never replace
  # something mainline already provides.
  #
  # All twelve patch files stay in ./patches/ deliberately, including the three
  # this refactor supersedes. They are no longer a patch stack — they are the
  # source material we vendor from:
  #
  #   01-devicetree.patch  holds the peripheral DT nodes (display, USB-C, audio,
  #                        NPU, VPU) that mainline's 119-line board DTS lacks.
  #                        Porting a peripheral means lifting its node from here
  #                        and ADDING it to mainline's DTS, not applying 01.
  #   02, 03               superseded entirely by mainline's pci-sky1.c,
  #                        reset-sky1.c, cix-mailbox.c and SCMI/clock support.
  #                        Kept only for reference; do not re-enable.
  cixPatches = [
    # ./patches/04-usb-phy-typec.patch      # drivers/phy/cix/  (absent upstream)
    # ./patches/05-display-drm-cix.patch    # linlon-dp, trilin-dpsub
    # Sky1 SCMI/DVFS glue for panthor. panthor itself is mainline; this adds the
    # power-domain and DVFS sequencing mainline has no way to express:
    #   panthor_pm_domain_init()     attach pd_gpu + perf as separate domains
    #   panthor_devfreq_scmi_init()  drive DVFS through the SCMI perf domain
    #                                rather than dev_pm_opp_set_rate()
    # Without it, panthor_hw_init() touches an unclocked/unpowered GPU and the
    # SoC raises a fatal abort. See the GPU node below for the matching DT shape.
    ./patches/06-gpu-panthor.patch
    # ./patches/07-audio-asoc.patch
    # ./patches/08-npu-armchina.patch
    # ./patches/09-vpu-linlon.patch
    # ./patches/11-misc-thermal-pwm.patch
    # ./patches/12-soc-firmware-dsp.patch
  ];

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

    # Enable Armv8 Cryptography Extensions (AES/NEON) to fix crypto/aegis128-neon-inner
    # assembler failures. Blunt (it applies to the whole build) but harmless here.
    NIX_CFLAGS_COMPILE = "-march=armv8-a+crypto";

    prePatch =
      (
        if cixPatches == [ ] then
          ''
            echo "Mainline-first build: no CIX patches applied."
          ''
        else
          ''
            echo "Applying additive CIX patches..."
            # NOTE: interpolate each path with "''${p}", never `toString p`.
            # toString only stringifies the path into the flake source, which is
            # not an input to this derivation and so does not exist inside the
            # build sandbox — the build fails with "No such file or directory"
            # even though the file is present in the repo. Interpolation copies
            # the file into the store and records the dependency.
            for p in ${lib.concatMapStringsSep " " (p: "${p}") cixPatches}; do
              echo "  Applying $(basename $p)..."
              patch -p1 --fuzz=0 < "$p"
            done
          ''
      )
      + ''

        # ── Additive: GPU node for panthor ──────────────────────────────────
        # mainline's sky1.dtsi describes no GPU at all, so DRM_PANTHOR builds
        # but has nothing to bind to and /sys/class/drm stays empty.
        #
        # This is written against mainline's own binding
        # (Documentation/devicetree/bindings/gpu/arm,mali-valhall-csf.yaml), NOT
        # lifted from the downstream DTS — that node is for ARM's proprietary
        # kbase driver ("arm,mali-valhall", physical-memory-group-manager,
        # protected-memory-allocator) and panthor would never match it.
        #
        # Register range, interrupt numbers and power domains come from the
        # downstream node; only the binding shape is different. panthor takes
        # the core clock via devm_clk_get(dev, NULL), i.e. index 0, then
        # "stacks"/"coregroup" optionally by name.
        #
        # soc@0 has no label in mainline, hence the &{/soc@0} path reference.
        # Appended rather than patched so there are no hunk offsets to drift.
        echo "Adding panthor GPU node to sky1-orion-o6.dts..."
        cat >> arch/arm64/boot/dts/cix/sky1-orion-o6.dts <<'DTSEOF'

        &{/soc@0} {
            gpu: gpu@15010000 {
                compatible = "arm,mali-valhall-csf";
                reg = <0x0 0x15010000 0x0 0x480000>;
                interrupts =
                    <GIC_SPI 237 IRQ_TYPE_LEVEL_HIGH 0>,
                    <GIC_SPI 238 IRQ_TYPE_LEVEL_HIGH 0>,
                    <GIC_SPI 239 IRQ_TYPE_LEVEL_HIGH 0>;
                interrupt-names = "job", "mmu", "gpu";
                clocks =
                    <&scmi_clk CLK_TREE_GPU_CLK_CORE>,
                    <&scmi_clk CLK_TREE_GPU_CLK_STACKS>;
                clock-names = "core", "stacks";
                /*
                 * Two power domains, named exactly "pd_gpu" and "perf".
                 *
                 * 06-gpu-panthor.patch requires this shape. Its
                 * panthor_devfreq_scmi_init() looks the perf domain up by name:
                 *     of_property_match_string(np, "power-domain-names", "perf")
                 * and its panthor_pm_domain_init() attaches both domains and
                 * drives DVFS through the SCMI perf domain with
                 * dev_pm_opp_set_opp() instead of dev_pm_opp_set_rate().
                 *
                 * Stock mainline panthor cannot do this. panthor_init_power()
                 * only picks up dev->pm_domain, which the genpd core populates
                 * for a SINGLE power-domain; with a list it attaches virtual
                 * devices nothing ever resumes. Three attempts proved it:
                 *   3 domains, no glue -> GPU unpowered, async SError
                 *   1 domain,  no glue -> SCMI clock enable timed out, sync abort
                 * Both faulted in panthor_hw_init+0x2c/0x34, its first GPU MMIO.
                 */
                power-domains =
                    <&smc_devpd SKY1_PD_GPU>,
                    <&scmi_dvfs SKY1_PERF_GPU_CORE>;
                power-domain-names = "pd_gpu", "perf";
                operating-points-v2 = <&gpu_opp_table>;
                #cooling-cells = <2>;
                status = "okay";

                gpu_opp_table: opp-table {
                    compatible = "operating-points-v2";
                    opp-350000000 {
                        opp-hz = /bits/ 64 <350000000>;
                    };
                    opp-600000000 {
                        opp-hz = /bits/ 64 <600000000>;
                    };
                    opp-800000000 {
                        opp-hz = /bits/ 64 <800000000>;
                    };
                    opp-1000000000 {
                        opp-hz = /bits/ 64 <1000000000>;
                    };
                };
            };
        };
        DTSEOF

        for want in 'arm,mali-valhall-csf' 'operating-points-v2' 'opp-1000000000'; do
          if ! grep -q "$want" arch/arm64/boot/dts/cix/sky1-orion-o6.dts; then
            echo "FATAL: GPU node incomplete, missing '$want' in the board DTS." >&2
            exit 1
          fi
        done
        echo "GPU node added."
      '';

    configurePhase = ''
      patchShebangs scripts
      patchShebangs tools

      # ── Phase 1: mainline arm64 defconfig ───────────────────────────────────
      # Upstream's own config. It already sets ARCH_CIX=y, PINCTRL_SKY1=y and
      # CIX_MBOX=y, so the Sky1-Linux defconfig is no longer needed — which also
      # drops the pile of unrelated SoC platforms (Amlogic, Marvell, Allwinner,
      # Renesas, Microchip, Realtek…) that config pulled in.
      make ARCH=arm64 defconfig

      # ── Phase 2: boot path ──────────────────────────────────────────────────
      # These are the difference between booting and not booting on this board.
      # Root is NVMe behind PCIe behind the SCMI clock/reset chain, so all of it
      # must be built in rather than modular.
      ./scripts/config --enable ARCH_CIX
      ./scripts/config --enable PCI_SKY1_HOST      # defconfig has =m; root needs =y
      ./scripts/config --enable PCIE_CADENCE
      ./scripts/config --enable PCIE_CADENCE_HOST
      ./scripts/config --enable PCI_ECAM
      # RESET_SKY1 is NOT in arm64 defconfig. Without it every device needing a
      # reset defers with -EPROBE_DEFER forever, including PCIe and so the root
      # device. This one line is the difference between booting and not.
      ./scripts/config --enable RESET_SKY1
      ./scripts/config --enable CIX_MBOX
      ./scripts/config --enable MAILBOX
      ./scripts/config --enable ARM_SCMI_PROTOCOL
      ./scripts/config --enable ARM_SCMI_TRANSPORT_MAILBOX
      ./scripts/config --enable COMMON_CLK_SCMI
      ./scripts/config --enable PINCTRL_SKY1
      ./scripts/config --enable BLK_DEV_NVME

      # ── Phase 3: console and diagnostics ────────────────────────────────────
      ./scripts/config --enable SERIAL_AMBA_PL011
      ./scripts/config --enable SERIAL_AMBA_PL011_CONSOLE
      ./scripts/config --enable EFI
      ./scripts/config --enable EFI_STUB
      ./scripts/config --enable EFI_EARLYCON
      ./scripts/config --enable DRM_SIMPLEDRM

      # ── Phase 4: NixOS requirements ─────────────────────────────────────────
      ./scripts/config --enable DEVTMPFS
      ./scripts/config --enable DEVTMPFS_MOUNT
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable SECCOMP
      ./scripts/config --enable BLK_DEV_INITRD
      ./scripts/config --enable RD_ZSTD
      ./scripts/config --enable RD_GZIP
      ./scripts/config --module BTRFS_FS
      ./scripts/config --module CRYPTO_BLAKE2B
      ./scripts/config --module CRYPTO_CRC32C
      ./scripts/config --module CRYPTO_XXHASH
      ./scripts/config --module NLS_CP437
      ./scripts/config --module NLS_UTF8
      ./scripts/config --enable FW_LOADER_COMPRESS
      ./scripts/config --enable FW_LOADER_COMPRESS_ZSTD

      # vfat for the ESP at /boot
      ./scripts/config --module VFAT_FS
      ./scripts/config --enable FAT_FS

      # TPM. arm64 defconfig gives TCG_TPM=y and TCG_TIS=m but NOT TCG_CRB, and
      # systemd-initrd hard-requires tpm_crb — without it the initrd build fails
      # with "modprobe: FATAL: Module tpm-crb not found", after the kernel has
      # already compiled. Gated below so it cannot regress silently again.
      ./scripts/config --module TCG_TIS
      ./scripts/config --module TCG_CRB

      # USB attached SCSI — "uas" is listed in boot.initrd.availableKernelModules
      ./scripts/config --module USB_UAS
      ./scripts/config --module USB_UHCI_HCD

      # AppArmor — required by security.apparmor.enable in the SOE security config
      ./scripts/config --enable SECURITY_APPARMOR
      ./scripts/config --enable DEFAULT_SECURITY_APPARMOR

      # zram — required by the NixOS zramSwap module
      ./scripts/config --module ZRAM
      ./scripts/config --enable ZRAM_DEF_COMP_ZSTD
      ./scripts/config --enable ZRAM_BACKEND_ZSTD
      ./scripts/config --enable LRU_GEN
      ./scripts/config --enable LRU_GEN_ENABLED

      # NixOS firewall / netfilter
      ./scripts/config --module NETFILTER_XT_MATCH_PKTTYPE
      ./scripts/config --module NETFILTER_XT_MATCH_IPRANGE
      ./scripts/config --module IP_NF_MATCH_RPFILTER
      ./scripts/config --module IP6_NF_MATCH_RPFILTER

      # Networking: in-kernel r8169 covers the RTL8125/8126 on this board.
      # If it turns out not to drive the 8126 properly, that is one driver to
      # carry as an additive patch — not a reason to fork the whole tree.
      ./scripts/config --module R8169
      ./scripts/config --module USB_NET_AX88179_178A
      ./scripts/config --module USB_NET_CDCETHER
      ./scripts/config --module USB_NET_CDC_NCM

      # Trim build size / time
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --disable DEBUG_INFO_BTF
      ./scripts/config --disable DEBUG_INFO_DWARF5
      ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
      ./scripts/config --disable DRM_AMDGPU
      ./scripts/config --disable DRM_NOUVEAU
      ./scripts/config --disable DRM_RADEON

      # The build sandbox has no /lib/firmware, so built-in firmware fails.
      ./scripts/config --set-str EXTRA_FIRMWARE ""

      make ARCH=arm64 olddefconfig

      # ── Phase 5: validation gate ────────────────────────────────────────────
      # Only boot-path and observability symbols. Peripheral symbols are added
      # back here as their patches are re-enabled above, so this list always
      # describes what the build actually promises.
      echo "Validating kernel configuration..."
      MISSING=0
      for opt in \
        ARCH_CIX OF OF_FLATTREE EFI_STUB EFI_EARLYCON \
        PINCTRL_SKY1 CIX_MBOX MAILBOX \
        ARM_SCMI_PROTOCOL ARM_SCMI_TRANSPORT_MAILBOX COMMON_CLK_SCMI \
        RESET_SKY1 \
        PCI_SKY1_HOST PCIE_CADENCE_HOST PCI_ECAM \
        BLK_DEV_NVME BTRFS_FS VFAT_FS RD_ZSTD \
        TCG_CRB TCG_TIS USB_UAS \
        SERIAL_AMBA_PL011_CONSOLE; do
        if ! grep -q "CONFIG_''${opt}=[ym]" .config; then
          echo "FATAL: CONFIG_''${opt} is not enabled in .config!" >&2
          MISSING=$((MISSING + 1))
        fi
      done
      if [ "$MISSING" -gt 0 ]; then
        echo "" >&2
        echo "ERROR: $MISSING required kernel config option(s) are missing." >&2
        exit 1
      fi

      # The whole point of this refactor: these must come from mainline.
      # BLK_DEV_NVME and PCI_SKY1_HOST must be built in, not modules, because
      # the root filesystem lives behind them.
      for opt in PCI_SKY1_HOST BLK_DEV_NVME RESET_SKY1 CIX_MBOX; do
        if ! grep -q "CONFIG_''${opt}=y" .config; then
          echo "FATAL: CONFIG_''${opt} must be built in (=y), not a module." >&2
          exit 1
        fi
      done
      echo "All critical kernel config options verified."
    '';

    buildPhase = ''
      make ARCH=arm64 -j$NIX_BUILD_CORES Image
      make ARCH=arm64 -j$NIX_BUILD_CORES dtbs
      make ARCH=arm64 -j$NIX_BUILD_CORES modules
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp .config $out/config

      # DTBs — mainline builds cix/sky1-orion-o6.dtb from ARCH_CIX
      mkdir -p $out/boot/dts/cix
      cp arch/arm64/boot/dts/cix/*.dtb $out/boot/dts/cix/
      mkdir -p $out/dtbs/cix
      cp arch/arm64/boot/dts/cix/*.dtb $out/dtbs/cix/

      make ARCH=arm64 INSTALL_MOD_PATH=$out modules_install

      # Populate the build directory for out-of-tree modules
      rm -f $out/lib/modules/*/build
      rm -f $out/lib/modules/*/source

      mkdir -p $out/lib/modules/${modDirVersion}/build
      cp Makefile Kbuild .config Module.symvers System.map $out/lib/modules/${modDirVersion}/build/

      cp -r include $out/lib/modules/${modDirVersion}/build/
      mkdir -p $out/lib/modules/${modDirVersion}/build/arch/arm64
      cp -r arch/arm64/include $out/lib/modules/${modDirVersion}/build/arch/arm64/
      cp arch/arm64/Makefile $out/lib/modules/${modDirVersion}/build/arch/arm64/

      cp -r scripts $out/lib/modules/${modDirVersion}/build/
      cp -r tools $out/lib/modules/${modDirVersion}/build/

      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.cmd" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.cmd" -exec rm -f {} +

      # Remove dangling symlinks that Nix's noBrokenSymlinks check would reject
      find $out/lib/modules/${modDirVersion}/build -xtype l -delete
    '';

    passthru = rec {
      modDirVersion = "7.2.0-rc5";
      version = modDirVersion;
      dev = kernelBuild;
      moduleBuildDependencies = [ ];
      configfile = "${kernelBuild}/config";
      # NOTE: these answers are approximations. nixpkgs modules that introspect
      # kernel config will get "yes" for everything, which is wrong but matches
      # the previous behaviour. Worth replacing with a real .config parser.
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
