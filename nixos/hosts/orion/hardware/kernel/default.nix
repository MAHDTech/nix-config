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
    # USB. Mainline 7.2 describes no USB on this SoC at all -- no usb, xhci,
    # dwc3, cdns3 or typec node anywhere in sky1.dtsi -- and the CIX PHYs
    # (cix,sky1-usb2-phy / -usb3-phy / -usbdp-phy) have no upstream driver.
    # usbcore and xhci-hcd register but nothing ever probes, so no keyboard.
    #
    # Verified to apply to 7.2 with zero conflicts before enabling, including
    # the two hunks that looked risky: drivers/usb/host/xhci-plat.c and the
    # cdns3 Kconfig that upstream restructured in this cycle.
    #
    # 11 of its 18 files are new; the rest are Kconfig/Makefile hooks plus
    # xhci-plat.c. Adds drivers/phy/cix/ and the cdnsp platform glue.
    ./patches/04-usb-phy-typec.patch
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
    # ArmChina Zhouyi NPU. Mainline 7.2 has no driver for it at all --
    # drivers/accel/ ships amdxdna, ethosu, habanalabs, ivpu, qaic and rocket,
    # and the tree contains zero matches for zhouyi/aipu/armchina. (ethosu is
    # ARM's Ethos-U microNPU, a different part.) So this one has to be carried.
    #
    # It is the safest patch in the set to carry: 92 files, 90 of them created
    # from /dev/null under drivers/misc/armchina-npu/. The only edits to
    # existing files are two one-line appends to drivers/misc/Kconfig and
    # drivers/misc/Makefile, so there is nothing for upstream churn to conflict
    # with -- unlike 04/05, which patch files mainline actively rewrites.
    ./patches/08-npu-armchina.patch
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

        # ── Fixup: drop the ACPI-only genpd lookup from 06-gpu-panthor ──────
        # panthor_devfreq_scmi_init() has two branches, DT and ACPI. The ACPI
        # one calls pm_genpd_lookup_by_name(), which does not exist in 7.2:
        #
        #   panthor_devfreq.c:348: error: implicit declaration of function
        #                          'pm_genpd_lookup_by_name'
        #
        # ORION boots DT-only (acpi=off on the kernel command line), so that
        # branch is dead code here. Null the lookup and let the existing
        # "if (!perf_genpd) return 0;" immediately below it bail out, rather
        # than inventing a replacement for an API we never execute.
        if grep -q 'pm_genpd_lookup_by_name' drivers/gpu/drm/panthor/panthor_devfreq.c; then
          sed -i 's|perf_genpd = pm_genpd_lookup_by_name(\"gpu_core\");|perf_genpd = NULL; /* ACPI path unused: ORION boots DT-only */|' \
            drivers/gpu/drm/panthor/panthor_devfreq.c
          if grep -q 'pm_genpd_lookup_by_name' drivers/gpu/drm/panthor/panthor_devfreq.c; then
            echo "FATAL: failed to neutralise pm_genpd_lookup_by_name()" >&2
            exit 1
          fi
          echo "Removed ACPI-only pm_genpd_lookup_by_name() call."
        fi

        # ── Fixup: Sky1 detection must match our DT compatible, not ACPI ────
        # 06-gpu-panthor identifies a Sky1 GPU with:
        #
        #   if (of_device_is_compatible(dev->of_node, "arm,mali-valhall"))
        #           return true;
        #   return acpi_dev_hid_uid_match(ACPI_COMPANION(dev), "CIXH5000", NULL);
        #
        # Our node uses "arm,mali-valhall-csf", the mainline panthor binding,
        # because "arm,mali-valhall" is ARM's proprietary kbase binding. So the
        # DT test missed, execution fell into the ACPI branch, and with acpi=off
        # ACPI_COMPANION() is NULL:
        #
        #   Unable to handle kernel NULL pointer dereference at 0x98
        #   pc : acpi_device_hid+0xc/0x48
        #   lr : panthor_is_sky1.isra.0+0x68/0xa4 [panthor]
        #      panthor_device_init -> panthor_probe -> panthor_init
        #
        # There are four such checks (Sky1 detection, clock setup, coherency and
        # reset paths). Rewrite them all to our compatible, keyed on the function
        # name so the of_device_id match table entry at panthor_drv.c is left
        # alone — that one legitimately lists "arm,mali-valhall" for binding.
        #
        # Then neutralise the ACPI fallbacks outright: this host is DT-only, and
        # acpi_dev_hid_uid_match() is not NULL-safe on a missing companion.
        for f in drivers/gpu/drm/panthor/*.c; do
          sed -i \
            -e 's|of_device_is_compatible(\([^;]*\), "arm,mali-valhall")|of_device_is_compatible(\1, "arm,mali-valhall-csf")|g' \
            -e 's|acpi_dev_hid_uid_match(ACPI_COMPANION([^)]*), "CIXH5000", NULL)|false /* DT-only host */|g' \
            "$f"
        done
        if grep -rn 'of_device_is_compatible([^;]*"arm,mali-valhall")' drivers/gpu/drm/panthor/ 2>/dev/null; then
          echo "FATAL: a bare arm,mali-valhall DT check survived the rewrite." >&2
          exit 1
        fi
        if grep -rn 'acpi_dev_hid_uid_match' drivers/gpu/drm/panthor/ 2>/dev/null; then
          echo "FATAL: an unguarded acpi_dev_hid_uid_match() survived." >&2
          exit 1
        fi
        echo "Sky1 detection rewritten for the arm,mali-valhall-csf DT binding."

        # ── Fixup: power the GPU explicitly under DT, not just under ACPI ───
        # 06-gpu-panthor powers SKY1_PD_GPU with a direct SMC SCMI call, but
        # only when there is no of_node:
        #
        #   /* This replicates what smc_devpd does under DT ... */
        #   if (!ptdev->base.dev->of_node) {
        #           if (panthor_is_sky1(ptdev))
        #                   sky1_smc_scmi_power_set(dev, SKY1_PD_GPU, 0);
        #   }
        #
        # i.e. the DT path trusts the smc_devpd genpd to do it. On this firmware
        # it does not: gpu_pd stays "off-0", and panthor_hw_init then SErrors on
        # its first GPU register access:
        #
        #   SError Interrupt on CPU7, code 0xbe000011
        #   pc : panthor_hw_init+0x34/0x820 [panthor]
        #
        # The glue's own domain attach is correct (dev_pm_domain_attach_by_id
        # plus device_link_add with DL_FLAG_RPM_ACTIVE), so the gap is below it,
        # in the SMC SCMI transport — which also logs
        # "Malformed reply - real_sz:8 calc_sz:4" against this EDK2 build.
        # The downstream product boots ACPI, so its DT path is the untested one.
        #
        # Drop the guard so the explicit power-up runs on DT as well. It is
        # idempotent: a POWER_STATE_SET on an already-on domain is a no-op.
        if grep -rq 'if (!ptdev->base.dev->of_node) {' drivers/gpu/drm/panthor/; then
          sed -i 's|if (!ptdev->base.dev->of_node) {|if (1) { /* DT too: smc_devpd does not power the GPU on this firmware */|' \
            drivers/gpu/drm/panthor/panthor_device.c
          grep -q 'DT too: smc_devpd does not power' drivers/gpu/drm/panthor/panthor_device.c || {
            echo "FATAL: failed to unguard the Sky1 SMC power-up" >&2; exit 1; }
          echo "Sky1 SMC GPU power-up now runs under DT as well."
        fi

        # ── Fixup: do not force ACE-Lite coherency on Sky1 ──────────────────
        # With the GPU finally powered and out of reset, panthor_hw_init()
        # succeeds and the GPU identifies itself:
        #
        #   [drm] Mali-G720-Immortalis id 0xc870 major 0x0 minor 0x0 status 0x8
        #   [drm] shader_present=0x550555 l2_present=0x1 tiler_present=0x1
        #
        # but probe then fails -524 (-ENOTSUPP):
        #
        #   [drm] Using ACE-Lite bus coherency (Sky1)
        #   [drm] *ERROR* ACE-Lite not supported by hardware
        #
        # The glue unconditionally forces ACE_LITE on Sky1, then a capability
        # check reads GPU_COHERENCY_FEATURES and finds the ACE_LITE bit clear,
        # so it bails. The downstream stack drove this GPU with ARM's kbase
        # driver, which does not perform that check, so the combination of
        # "force ACE-Lite" plus panthor's capability gate was never exercised.
        #
        # Believe the hardware: select COHERENCY_NONE instead. panthor already
        # handles that path and simply uses non-cacheable memory attributes,
        # which costs some cache maintenance but is functionally correct.
        python3 - <<'PYEOF'
        import io, re, sys
        p = "drivers/gpu/drm/panthor/panthor_gpu.c"
        try:
            s = open(p).read()
        except FileNotFoundError:
            sys.exit(0)
        old_a = 'ptdev->coherency_mode = PANTHOR_COHERENCY_ACE_LITE;\n'
        old_b = '\t\tdrm_info(&ptdev->base, "Using ACE-Lite bus coherency (Sky1)\\n");'
        new_a = 'ptdev->coherency_mode = PANTHOR_COHERENCY_NONE;\n'
        new_b = '\t\tdrm_info(&ptdev->base, "Sky1: GPU reports no ACE-Lite; using non-coherent\\n");'
        old = old_a + old_b
        new = new_a + new_b
        if old in s:
            open(p, "w").write(s.replace(old, new, 1))
            print("Sky1 coherency changed from forced ACE-Lite to non-coherent.")
        elif "no ACE-Lite; using non-coherent" in s:
            print("Sky1 coherency fixup already applied.")
        else:
            print("FATAL: could not find the Sky1 ACE-Lite assignment", file=sys.stderr)
            sys.exit(1)
        PYEOF

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
                /*
                 * TWO ranges, in this order. Mainline's binding says
                 * "reg: maxItems: 1", but once panthor_is_sky1() returns true
                 * the glue takes the Sky1 path and indexes them explicitly:
                 *
                 *   ptdev->iomem         = ..._get_and_ioremap_resource(pdev, 1, &res);
                 *   ptdev->sky1_rcsu_reg = ..._ioremap_resource(pdev, 0);
                 *
                 * so index 0 must be the RCSU block and index 1 the GPU. With a
                 * single range index 1 is NULL and probe fails:
                 *   panthor 15010000.gpu: error -EINVAL: invalid resource (null)
                 *   probe with driver panthor failed with error -22
                 *
                 * The RCSU range is load-bearing, not decorative: the glue uses
                 * it for power-gating control (sky1_rcsu_reg + 0x218) and for
                 * shader-core harvesting (+ 0x304).
                 */
                reg =
                    <0x0 0x15000000 0x0 0x10000>,
                    <0x0 0x15010000 0x0 0x480000>;
                reg-names = "gpu_rcsu", "gpu";
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
                /*
                 * The GPU comes out of reset here, and without this it never
                 * does. panthor_device_init() runs, in order:
                 *
                 *   if (ptdev->gpu_reset) { assert; udelay; deassert; }
                 *   if (ptdev->sky1_rcsu_reg) { ungate qchannel clock }
                 *   panthor_hw_init(ptdev);            <- first GPU MMIO
                 *
                 * and the glue fetches it by name:
                 *   devm_reset_control_get_optional(dev, "gpu_reset")
                 *
                 * Omitting resets leaves ptdev->gpu_reset NULL, so the whole
                 * assert/deassert is skipped and the GPU is still held in reset
                 * when hw_init touches it. That is what produced:
                 *
                 *   panthor 15000000.gpu: GPU power domain 21 powered on via SMC SCMI
                 *   SError Interrupt on CPU11, code 0xbe000011
                 *   pc : panthor_hw_init+0x34/0x820 [panthor]
                 *
                 * i.e. powered, but not released from reset.
                 *
                 * s5_syscon is mainline's label for the reset controller the
                 * downstream DTS calls "src" (both are syscon@16000000). The
                 * IDs are numeric because mainline ships no sky1-reset.h:
                 *   SKY1_GPU_RCSU_RESET_N = 119, SKY1_GPU_RESET_N = 9
                 */
                resets = <&s5_syscon 119>, <&s5_syscon 9>;
                reset-names = "gpu_rcsu_reset", "gpu_reset";
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

        # ── Additive: NPU node for 08-npu-armchina ──────────────────────────
        # mainline's sky1.dtsi describes no NPU, so the driver builds and binds
        # to nothing. Lifted from the downstream node (aipu@14260000) with three
        # deliberate changes, each forced by mainline:
        #
        #  1. iommus = <&smmu_mmhub 0x1e>  DROPPED. mainline's sky1.dtsi has no
        #     SMMU nodes at all, so the phandle would not resolve. This is not
        #     cosmetic: aipu_mm.c takes a different path when there is no IOMMU
        #        if (!mm->has_iommu) mm->res_cnt = aipu_mm_add_reserved_regions(mm);
        #        else                mm->res_cnt = aipu_mm_add_iova_region(mm);
        #     and its own comment says memory-region is optional only when
        #     behind an IOMMU. Without one the carveout below is mandatory.
        #
        #  2. NPU_DFS_DOMAIN_ID -> SKY1_PERF_NPU. Same value (8), but that macro
        #     is downstream-only; sky1-power.h is what mainline ships. Confirmed
        #     against the live genpd summary, which names the domain "npu_dfs_8".
        #
        #  3. The reserved region moved off downstream's 0x90000000. On this
        #     board's firmware memory map that address is not safe:
        #        86000000-9fffffff : System RAM
        #        a0000000-a7ffffff : reserved      <-- inside 0x90000000+0x20000000
        #     so a 512M no-map carveout at 0x90000000 would straddle memory the
        #     firmware already claimed. 0xb0000000 sits wholly inside the
        #     a8000000-fffdffff System RAM span and clears the reserved hole at
        #     0xfbfe0000. Verified against /proc/iomem on the running machine.
        #
        # The region node MUST be named "memory@...". aipu_mm.c matches on the
        # node name literally:
        #     if (!strcmp(np->name, "memory")) type = AIPU_MEM_REGION_TYPE_MEMORY;
        #     else dev_err("invalid memory region name: %s")
        # and then calls of_address_to_resource(np, 0), so it also needs a fixed
        # reg -- a sizeless "reusable" pool cannot be used here.
        #
        # No resets property: unlike panthor, this driver never calls
        # reset_control_get, so there is nothing to hand it. The SMC power
        # domains bring the cores up.
        echo "Adding ArmChina NPU node to sky1-orion-o6.dts..."
        cat >> arch/arm64/boot/dts/cix/sky1-orion-o6.dts <<'DTSEOF'

        &{/reserved-memory} {
            aipu_res_0: memory@b0000000 {
                compatible = "shared-dma-pool";
                no-map;
                reg = <0x0 0xb0000000 0x0 0x20000000>;
            };
        };

        &{/soc@0} {
            npu: aipu@14260000 {
                compatible = "armchina,zhouyi";
                reg = <0x0 0x14260000 0x0 0x10000>;
                interrupts = <GIC_SPI 327 IRQ_TYPE_LEVEL_HIGH 0>;
                /*
                 * core_mask is read with device_property_read_u32() and gates
                 * the whole probe in sky1_npu_probe():
                 *     if (mask == 0x1)                 CIX_NPU_PD_NUM = 1;
                 *     else if (mask == 0x0 || == 0x2)  return 0;  <- silent no-op
                 * so 3 means "all three cores", matching the three pd_core
                 * domains below. The underscore spelling is what the driver
                 * reads; it is not a typo for core-mask.
                 */
                core_mask = <3>;
                /*
                 * Four domains. sky1.c attaches the three core domains by name
                 * in sky1_npu_attach_pd() and the perf domain separately in
                 * sky1_npu_devfreq_init(), both via dev_pm_domain_attach_by_name,
                 * so the names matter and the order does not.
                 */
                power-domains =
                    <&smc_devpd SKY1_PD_NPU_CORE0>,
                    <&smc_devpd SKY1_PD_NPU_CORE1>,
                    <&smc_devpd SKY1_PD_NPU_CORE2>,
                    <&scmi_dvfs SKY1_PERF_NPU>;
                power-domain-names = "pd_core0", "pd_core1", "pd_core2", "perf";
                /* <cluster, partition> pairs; one x2 cluster -> partition 0 */
                cluster-partition = <0 0>;
                /* 1 = global memory shared by tasks of every QoS level */
                gm-policy = <1>;
                memory-region = <&aipu_res_0>;
                status = "okay";
            };
        };
        DTSEOF

        # sky1-power.h is a plain header next to the DTS, not a dt-bindings one,
        # and sky1-orion-o6.dts does not include it -- the GPU node got away with
        # SKY1_PD_GPU only because sky1.dtsi pulls it in. Assert rather than
        # assume, because an unresolved macro is a dtc syntax error, not a
        # silently-zero cell.
        if ! grep -q 'SKY1_PD_NPU_CORE0' arch/arm64/boot/dts/cix/sky1-power.h; then
          echo "FATAL: sky1-power.h has no SKY1_PD_NPU_CORE0." >&2
          exit 1
        fi
        for want in 'armchina,zhouyi' 'SKY1_PERF_NPU' 'aipu_res_0'; do
          if ! grep -q "$want" arch/arm64/boot/dts/cix/sky1-orion-o6.dts; then
            echo "FATAL: NPU node incomplete, missing '$want' in the board DTS." >&2
            exit 1
          fi
        done
        echo "NPU node added."

        # ── Fixup: cdnsp-plat never starts a role on 7.2 ────────────────────
        # Symptom: all four controllers bound, probe returned 0, nothing was
        # logged -- and no xHCI host ever appeared.
        #
        #   9250310.usb            -> cdnsp-sky1
        #   9260000.usb-controller -> cdns-usbssp
        #   /sys/bus/usb/devices/  -> empty
        #
        # Cause: 7.2 split cdns_init() and cdns_core_init_role() into two
        # separately exported functions; cdns_init() no longer starts a role.
        # Mainline's own cdns3-plat.c therefore does four things:
        #
        #   ret = cdns_init(cdns);
        #   cdns->gadget_init = cdns3_plat_gadget_init;
        #   cdns->host_init   = cdns3_plat_host_init;
        #   ret = cdns_core_init_role(cdns);
        #
        # 04's cdnsp-plat.c was written when cdns_init() did both, so it sets
        # gadget_init, calls cdns_init(), and stops. host_init stays NULL and no
        # role is ever started. That is why the failure was silent: the -ENXIO
        # for a NULL host_init lives inside cdns_core_init_role(), which never
        # ran. host_init is only ever READ in core.c -- the platform glue has to
        # assign it.
        #
        # cdnsp-plat.c also lacks the host-export.h include, so cdns_host_init
        # is not even declared.
        #
        # The match strings are built from \t escapes rather than literal tabs,
        # so neither nixfmt reindentation nor editorconfig can silently change
        # what is being compared against the kernel source.
        python3 - <<'PYEOF'
        import sys

        p = "drivers/usb/cdns3/cdnsp-plat.c"
        s = open(p).read()

        if "cdns_core_init_role" in s:
            print("cdnsp-plat role init fixup already applied.")
            sys.exit(0)

        inc_old = '#include "gadget-export.h"\n'
        inc_new = '#include "gadget-export.h"\n#include "host-export.h"\n'
        if inc_old not in s:
            print("FATAL: cdnsp-plat.c has no gadget-export.h include", file=sys.stderr)
            sys.exit(1)
        s = s.replace(inc_old, inc_new, 1)

        old = (
            "\tcdns->gadget_init = cdnsp_gadget_init;\n"
            "\n"
            "\tret = cdns_init(cdns);\n"
            "\tif (ret)\n"
            "\t\tgoto err_cdns_init;\n"
        )
        new = (
            "\tcdns->gadget_init = cdnsp_gadget_init;\n"
            "\n"
            "\tret = cdns_init(cdns);\n"
            "\tif (ret)\n"
            "\t\tgoto err_cdns_init;\n"
            "\n"
            "\t/*\n"
            "\t * 7.2 split cdns_init() and cdns_core_init_role(). Without the\n"
            "\t * call below the controller binds, probe returns 0, and no role\n"
            "\t * is ever started, so no xHCI host is registered and no port\n"
            "\t * enumerates.\n"
            "\t */\n"
            "\tcdns->host_init = cdns_host_init;\n"
            "\n"
            "\tret = cdns_core_init_role(cdns);\n"
            "\tif (ret)\n"
            "\t\tgoto err_cdns_init_role;\n"
        )
        if old not in s:
            print("FATAL: cdns_init call site not found in cdnsp-plat.c", file=sys.stderr)
            sys.exit(1)
        s = s.replace(old, new, 1)

        old_err = "err_cdns_init:\n\tset_phy_power_off(cdns);"
        new_err = (
            "err_cdns_init_role:\n\tcdns_remove(cdns);\n"
            "err_cdns_init:\n\tset_phy_power_off(cdns);"
        )
        if old_err not in s:
            print("FATAL: err_cdns_init label not found", file=sys.stderr)
            sys.exit(1)
        s = s.replace(old_err, new_err, 1)

        open(p, "w").write(s)
        print("cdnsp-plat now sets host_init and calls cdns_core_init_role.")
        PYEOF

        # ── Fixup: 04's cdns3 Makefile declares two self-composite objects ──
        # The patch adds:
        #     cdnsp-sky1-y := cdnsp-sky1.o
        #     obj-$(CONFIG_USB_CDNSP_SKY1) += cdnsp-sky1.o
        # which tells kbuild that the composite module cdnsp-sky1.o is built
        # FROM cdnsp-sky1.o, i.e. from itself:
        #
        #   make: Circular drivers/usb/cdns3/cdnsp-sky1.o <- cdnsp-sky1.o
        #         dependency dropped.
        #   ld.bfd: input file 'cdnsp-sky1.o' is the same as output file
        #
        # A single-file module needs only the obj- line; the "-y :=" line is
        # what creates the cycle. Same mistake for cdnsp-plat. Drop both lines
        # rather than rewriting the Makefile, so the patch stays recognisable.
        for m in cdnsp-sky1 cdnsp-plat; do
          if grep -q "^$m-y := $m.o$" drivers/usb/cdns3/Makefile; then
            sed -i "/^$m-y := $m\.o$/d" drivers/usb/cdns3/Makefile
            echo "Dropped self-composite $m-y from the cdns3 Makefile."
          fi
        done
        if grep -qE '^(cdnsp-sky1|cdnsp-plat)-y' drivers/usb/cdns3/Makefile; then
          echo "FATAL: a self-composite cdnsp object survived the fixup." >&2
          exit 1
        fi

        # ── Additive: USB nodes for 04-usb-phy-typec ────────────────────────
        # mainline's sky1.dtsi describes no USB at all: no usb, xhci, dwc3,
        # cdns3 or typec node anywhere. usbcore and xhci-hcd are built and
        # registered, but nothing ever probes, which is why /sys/bus/usb/devices
        # is empty and no keyboard enumerates.
        #
        # The board has TEN controllers, all Cadence USBSSP behind a CIX wrapper:
        #   usbhs_0..3   USB2 only, high-speed, host, and crucially NO phys
        #                property at all -- no PHY dependency to get wrong
        #   usbss_4..5   USB3, fed by the plain "cix,sky1-usb3-phy" (usb3_phy4)
        #   usbss_0..3   USB3 on the Type-C ports, fed by the usbdp combo PHY
        #
        # Every clock and reset ID these need is ALREADY in mainline's headers
        # (all 57 checked before writing this), so only the nodes were missing.
        #
        # Three deliberate departures from the downstream board file:
        #
        #  1. dr_mode = "host" everywhere. Downstream runs usbss_0/1/4/5 as
        #     "otg" with usb-role-switch and endpoints wired to an rts5453 PD
        #     controller over I2C. Role switching needs that whole chain; host
        #     mode needs none of it and is what makes a keyboard work. The PD
        #     controller is in 04's typec/ directory and can be added later.
        #
        #  2. No DisplayPort alt-mode. The dp-port sub-nodes stay disabled --
        #     they would bind to a display driver that is not ported, so
        #     enabling them buys nothing and adds a probe that can fail.
        #
        #  3. No orientation-switch / mode-switch / port endpoints on the usbdp
        #     PHYs. Those exist to let the PD controller flip lanes on cable
        #     orientation; with no PD controller there is nothing to flip them.
        #
        # "src" in the downstream DTS is mainline's s5_syscon (syscon@16000000),
        # confirmed by the reset IDs living in cix,sky1-s5-system-control.h.
        # The USB nodes reference reset IDs by name (SKY1_USBC_HS0_PRST_N and
        # friends). mainline's sky1.dtsi includes arm-gic.h, cix,sky1.h and
        # sky1-power.h but NOT the reset bindings, so those symbols do not
        # resolve and dtc fails the whole board DTB:
        #
        #   Lexical error: sky1-orion-o6.dts:283.30-50
        #                  Unexpected 'SKY1_USBC_HS0_PRST_N'
        #   FATAL ERROR: Syntax error parsing input tree
        #
        # The GPU node sidesteps this by using bare numbers (&s5_syscon 119),
        # which is fine for two IDs and unreadable for twenty. Pull the header
        # in instead. Inserted after the existing includes rather than appended,
        # because a #include has to precede its first use.
        if ! grep -q 'cix,sky1-s5-system-control.h' arch/arm64/boot/dts/cix/sky1-orion-o6.dts; then
          sed -i '/#include "sky1-pinfunc.h"/a #include <dt-bindings/reset/cix,sky1-s5-system-control.h>' \
            arch/arm64/boot/dts/cix/sky1-orion-o6.dts
        fi
        grep -q 'cix,sky1-s5-system-control.h' arch/arm64/boot/dts/cix/sky1-orion-o6.dts || {
          echo "FATAL: could not add the reset bindings include to the board DTS." >&2
          exit 1
        }

        echo "Adding USB nodes to sky1-orion-o6.dts..."
        cat >> arch/arm64/boot/dts/cix/sky1-orion-o6.dts <<'USBEOF'

        &{/soc@0} {
            /*
              * USB2 high-speed host controllers. These are the safest of the
              * ten: high-speed only, host only, and no PHY phandle to resolve.
              * If anything USB works at all, it should be these.
              */
            sky1_usbhs_0: usb@9250000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x09250310 0x0 0x4>, <0x0 0x09250400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_HS0_PRST_N>,
                          <&s5_syscon SKY1_USBC_HS0_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB2_0_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB2_0_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB2_0_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB2_0_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbhs_0: usb-controller@9260000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x9260000 0x0 0x4000>,
                          <0x0 0x9264000 0x0 0x4000>,
                          <0x0 0x9268000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 240 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 240 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 241 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 240 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "high-speed";
                    dr_mode = "host";
                    status = "okay";
                };
            };

            sky1_usbhs_1: usb@9280000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x09280310 0x0 0x4>, <0x0 0x09280400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_HS1_PRST_N>,
                          <&s5_syscon SKY1_USBC_HS1_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB2_1_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB2_1_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB2_1_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB2_1_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbhs_1: usb-controller@9290000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x9290000 0x0 0x4000>,
                          <0x0 0x9294000 0x0 0x4000>,
                          <0x0 0x9298000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 243 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 243 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 244 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 243 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "high-speed";
                    dr_mode = "host";
                    status = "okay";
                };
            };

            sky1_usbhs_2: usb@92b0000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x092b0310 0x0 0x4>, <0x0 0x092b0400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_HS2_PRST_N>,
                          <&s5_syscon SKY1_USBC_HS2_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB2_2_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB2_2_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB2_2_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB2_2_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbhs_2: usb-controller@92c0000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x92c0000 0x0 0x4000>,
                          <0x0 0x92c4000 0x0 0x4000>,
                          <0x0 0x92c8000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 246 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 246 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 247 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 246 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "high-speed";
                    dr_mode = "host";
                    status = "okay";
                };
            };

            sky1_usbhs_3: usb@92e0000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x092e0310 0x0 0x4>, <0x0 0x092e0400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_HS3_PRST_N>,
                          <&s5_syscon SKY1_USBC_HS3_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB2_3_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB2_3_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB2_3_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB2_3_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbhs_3: usb-controller@92f0000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x92f0000 0x0 0x4000>,
                          <0x0 0x92f4000 0x0 0x4000>,
                          <0x0 0x92f8000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 249 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 249 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 250 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 249 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "high-speed";
                    dr_mode = "host";
                    status = "okay";
                };
            };

            /*
              * USB3 PHY feeding the two Type-A SuperSpeed controllers. One PHY
              * block with two ports; each usbss takes one.
              */
            usb3_phy4: usb-phy@9210000 {
                #address-cells = <1>;
                #size-cells = <0>;
                compatible = "cix,sky1-usb3-phy";
                reg = <0x0 0x09210000 0x0 0x40000>;
                resets = <&s5_syscon SKY1_USBPHY_SS_RST_N>,
                          <&s5_syscon SKY1_USBPHY_SS_PST_N>;
                reset-names = "reset", "preset";
                clocks = <&scmi_clk CLK_TREE_USB3A_PHY3_GATE>,
                          <&scmi_clk CLK_TREE_USB3A_PHY_x2_REF>;
                clock-names = "apb_clk", "ref_clk";
                cix,usbphy_syscon = <&s5_syscon>;
                status = "okay";

                usb3_phy4_0: usb-port@0 {
                    #phy-cells = <0>;
                    reg = <0>;
                    id = <0>;
                    status = "okay";
                };
                usb3_phy4_1: usb-port@1 {
                    #phy-cells = <0>;
                    reg = <1>;
                    id = <1>;
                    status = "okay";
                };
            };

            sky1_usbss_4: usb@91c0300 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x091c0314 0x0 0x4>, <0x0 0x091c0400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_SS2_PRST_N>,
                          <&s5_syscon SKY1_USBC_SS2_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB3A_H0_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB3A_0_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB3A_H0_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB3A_0_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbss_4: usb-controller@91d0000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x91d0000 0x0 0x4000>,
                          <0x0 0x91d4000 0x0 0x4000>,
                          <0x0 0x91d8000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 252 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 252 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 253 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 252 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "super-speed-plus";
                    dr_mode = "host";
                    phys = <&usb3_phy4_0>;
                    phy-names = "cdnsp,usb3-phy";
                    usb3-lpm-capable;
                    status = "okay";
                };
            };

            sky1_usbss_5: usb@91c0304 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x091c0324 0x0 0x4>, <0x0 0x091c0410 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_SS3_PRST_N>,
                          <&s5_syscon SKY1_USBC_SS3_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB3A_H1_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB3A_1_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB3A_H1_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB3A_1_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbss_5: usb-controller@91e0000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x91e0000 0x0 0x4000>,
                          <0x0 0x91e4000 0x0 0x4000>,
                          <0x0 0x91e8000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 257 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 257 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 258 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 257 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "super-speed-plus";
                    dr_mode = "host";
                    phys = <&usb3_phy4_1>;
                    phy-names = "cdnsp,usb3-phy";
                    usb3-lpm-capable;
                    status = "okay";
                };
            };
        };

        /*
          * cdnsp-sky1 refuses to probe without an index:
          *
          *   ret = of_alias_get_id(dev->of_node, "usb");
          *   if (ret == -ENODEV) device_property_read_u32(dev, "id", &ret);
          *   if (ret < 0 || ret > 9) { dev_err("get alias failed."); return ret; }
          *
          * which is exactly what the first load produced:
          *   cdnsp-sky1 9250310.usb: get alias failed.   (x4)
          *
          * The number is NOT arbitrary. It indexes sky1_usb_signals[], the
          * table of USB_MODE_STRAP bits in the S5 syscon, so the wrong value
          * writes another controller's mode bits:
          *
          *   U3_TYPEA_CTRL0_ID 4   U2_HOST0_ID 6   U2_HOST2_ID 8
          *   U3_TYPEA_CTRL1_ID 5   U2_HOST1_ID 7   U2_HOST3_ID 9
          *
          * These match the downstream board file's aliases one for one. The
          * enum also settles which ports these are: usbss_4/5 are named
          * U3_TYPEA_*, i.e. the USB3 Type-A sockets.
          *
          * usb4/usb5 are declared now even though those nodes are disabled for
          * this attempt, so enabling them later needs no second change here.
          */
        /*
          * Type-C controllers. Four more USBSSP instances, each fed by a usbdp
          * combo PHY that carries both USB3 and DisplayPort lanes.
          *
          * Deliberately NOT carried over from the downstream board file:
          *   orientation-switch / mode-switch / svid and the port endpoints,
          *   which exist so an rts5453 PD controller can flip lanes when a cable
          *   is turned over. There is no PD controller wired up here, so nothing
          *   would drive them.
          *   dr_mode = "otg" with usb-role-switch, for the same reason -- host
          *   is what makes a keyboard or a dock's hub work.
          *
          * default_conf is kept: it is what the PHY falls back to with no PD
          * negotiation. 0x03 on 0/1 (USB3 + DP), 0x02 on 2/3, matching
          * downstream. The dp-port children stay disabled -- DisplayPort here
          * needs the unported display driver, and the firmware is already
          * scanning out over the dock's DP without it.
          */
        &{/soc@0} {
            usbc_phy0: usb-phy@9030000 {
                #address-cells = <1>;
                #size-cells = <0>;
                compatible = "cix,sky1-usbdp-phy";
                reg = <0x0 0x9030000 0x0 0x40000>;
                resets = <&s5_syscon SKY1_USB_DP_PHY0_RST_N>,
                          <&s5_syscon SKY1_USB_DP_PHY0_PRST_N>;
                reset-names = "reset", "preset";
                clocks = <&scmi_clk CLK_TREE_USB3C_DRD_PHY3_GATE>;
                clock-names = "pclk";
                cix,usbphy_syscon = <&s5_syscon>;
                default_conf = /bits/ 8 <0x03>;
                status = "okay";

                usb3_phy0: usb-port {
                    #phy-cells = <0>;
                    reg = <0x0>;
                    status = "okay";
                };
                usbc0_dp_phy: dp-port {
                    #phy-cells = <0>;
                    reg = <0x1>;
                    status = "disabled";
                };
            };

            usbc_phy1: usb-phy@90a0000 {
                #address-cells = <1>;
                #size-cells = <0>;
                compatible = "cix,sky1-usbdp-phy";
                reg = <0x0 0x90a0000 0x0 0x40000>;
                resets = <&s5_syscon SKY1_USB_DP_PHY1_RST_N>,
                          <&s5_syscon SKY1_USB_DP_PHY1_PRST_N>;
                reset-names = "reset", "preset";
                clocks = <&scmi_clk CLK_TREE_USB3C_0_PHY3_GATE>;
                clock-names = "pclk";
                cix,usbphy_syscon = <&s5_syscon>;
                default_conf = /bits/ 8 <0x03>;
                status = "okay";

                usb3_phy1: usb-port {
                    #phy-cells = <0>;
                    reg = <0x0>;
                    status = "okay";
                };
                usbc1_dp_phy: dp-port {
                    #phy-cells = <0>;
                    reg = <0x1>;
                    status = "disabled";
                };
            };

            usbc_phy2: usb-phy@9110000 {
                #address-cells = <1>;
                #size-cells = <0>;
                compatible = "cix,sky1-usbdp-phy";
                reg = <0x0 0x9110000 0x0 0x40000>;
                resets = <&s5_syscon SKY1_USB_DP_PHY2_RST_N>,
                          <&s5_syscon SKY1_USB_DP_PHY2_PRST_N>;
                reset-names = "reset", "preset";
                clocks = <&scmi_clk CLK_TREE_USB3C_1_PHY3_GATE>;
                clock-names = "pclk";
                cix,usbphy_syscon = <&s5_syscon>;
                default_conf = /bits/ 8 <0x02>;
                status = "okay";

                usb3_phy2: usb-port {
                    #phy-cells = <0>;
                    reg = <0x0>;
                    status = "disabled";
                };
                usbc2_dp_phy: dp-port {
                    #phy-cells = <0>;
                    reg = <0x1>;
                    status = "disabled";
                };
            };

            usbc_phy3: usb-phy@9180000 {
                #address-cells = <1>;
                #size-cells = <0>;
                compatible = "cix,sky1-usbdp-phy";
                reg = <0x0 0x9180000 0x0 0x40000>;
                resets = <&s5_syscon SKY1_USB_DP_PHY3_RST_N>,
                          <&s5_syscon SKY1_USB_DP_PHY3_PRST_N>;
                reset-names = "reset", "preset";
                clocks = <&scmi_clk CLK_TREE_USB3C_2_PHY3_GATE>;
                clock-names = "pclk";
                cix,usbphy_syscon = <&s5_syscon>;
                default_conf = /bits/ 8 <0x02>;
                status = "okay";

                usb3_phy3: usb-port {
                    #phy-cells = <0>;
                    reg = <0x0>;
                    status = "disabled";
                };
                usbc3_dp_phy: dp-port {
                    #phy-cells = <0>;
                    reg = <0x1>;
                    status = "disabled";
                };
            };

            sky1_usbss_0: usb@9000000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x09000310 0x0 0x4>, <0x0 0x09000400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_SS0_PRST_N>,
                          <&s5_syscon SKY1_USBC_SS0_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB3C_DRD_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB3C_DRD_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB3C_DRD_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB3C_DRD_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbss_0: usb-controller@9010000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x9010000 0x0 0x4000>,
                          <0x0 0x9014000 0x0 0x4000>,
                          <0x0 0x9018000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 262 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 262 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 263 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 262 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "super-speed-plus";
                    dr_mode = "host";
                    phys = <&usb3_phy0>;
                    phy-names = "cdnsp,usb3-phy";
                    usb3-lpm-capable;
                    status = "okay";
                };
            };

            sky1_usbss_1: usb@9070000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x09070310 0x0 0x4>, <0x0 0x09070400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_SS1_PRST_N>,
                          <&s5_syscon SKY1_USBC_SS1_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB3C_H0_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB3C_0_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB3C_H0_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB3C_0_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                status = "okay";

                usbss_1: usb-controller@9080000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x9080000 0x0 0x4000>,
                          <0x0 0x9084000 0x0 0x4000>,
                          <0x0 0x9088000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 268 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 268 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 269 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 268 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    maximum-speed = "super-speed-plus";
                    dr_mode = "host";
                    phys = <&usb3_phy1>;
                    phy-names = "cdnsp,usb3-phy";
                    usb3-lpm-capable;
                    status = "okay";
                };
            };

            sky1_usbss_2: usb@90e0000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x090e0310 0x0 0x4>, <0x0 0x090e0400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_SS4_PRST_N>,
                          <&s5_syscon SKY1_USBC_SS4_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB3C_H1_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB3C_1_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB3C_H1_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB3C_1_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                u3-port-disable;
                status = "okay";

                usbss_2: usb-controller@90f0000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x90f0000 0x0 0x4000>,
                          <0x0 0x90f4000 0x0 0x4000>,
                          <0x0 0x90f8000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 274 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 274 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 275 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 274 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    dr_mode = "host";
                    status = "okay";
                };
            };

            sky1_usbss_3: usb@9150000 {
                compatible = "cix,sky1-usbssp";
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                reg = <0x0 0x09150310 0x0 0x4>, <0x0 0x09150400 0x0 0x4>;
                reg-names = "axi_property", "controller_status";
                resets = <&s5_syscon SKY1_USBC_SS5_PRST_N>,
                          <&s5_syscon SKY1_USBC_SS5_RST_N>;
                reset-names = "usb_preset", "usb_reset";
                clocks = <&scmi_clk CLK_TREE_USB3C_H2_CLK_SOF>,
                          <&scmi_clk CLK_TREE_USB3C_2_AXI_GATE>,
                          <&scmi_clk CLK_TREE_USB3C_H2_CLK_LPM>,
                          <&scmi_clk CLK_TREE_USB3C_2_APB_GATE>;
                clock-names = "sof_clk", "usb_aclk", "lpm_clk", "usb_pclk";
                cix,usb_syscon = <&s5_syscon>;
                axi_bmax_value = <0x7>;
                sof_clk_freq = <8000000>;
                lpm_clk_freq = <32000>;
                u3-port-disable;
                status = "okay";

                usbss_3: usb-controller@9160000 {
                    compatible = "cdns,usbssp";
                    reg = <0x0 0x9160000 0x0 0x4000>,
                          <0x0 0x9164000 0x0 0x4000>,
                          <0x0 0x9168000 0x0 0x8000>;
                    reg-names = "otg", "dev", "xhci";
                    interrupts = <GIC_SPI 280 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 280 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 281 IRQ_TYPE_LEVEL_HIGH 0>,
                                  <GIC_SPI 280 IRQ_TYPE_LEVEL_HIGH 0>;
                    interrupt-names = "host", "peripheral", "otg", "wakeup";
                    dr_mode = "host";
                    status = "okay";
                };
            };
        };

        &{/aliases} {
            usb0 = &sky1_usbss_0;
            usb1 = &sky1_usbss_1;
            usb2 = &sky1_usbss_2;
            usb3 = &sky1_usbss_3;
            usb4 = &sky1_usbss_4;
            usb5 = &sky1_usbss_5;
            usb6 = &sky1_usbhs_0;
            usb7 = &sky1_usbhs_1;
            usb8 = &sky1_usbhs_2;
            usb9 = &sky1_usbhs_3;
        };
        USBEOF

        for want in 'cix,sky1-usbssp' 'cdns,usbssp' 'cix,sky1-usb3-phy' 'sky1_usbhs_0' 'usb6 = &sky1_usbhs_0'; do
          if ! grep -q "$want" arch/arm64/boot/dts/cix/sky1-orion-o6.dts; then
            echo "FATAL: USB nodes incomplete, missing '$want' in the board DTS." >&2
            exit 1
          fi
        done
        echo "USB nodes added."
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

      # ── ArmChina Zhouyi NPU (08-npu-armchina) ───────────────────────────────
      # Deliberately a MODULE, not built in. Every unbootable state on this
      # machine so far came from a driver faulting during boot-time probe --
      # iwlwifi SErroring on the unpowered AX210, panthor aborting in
      # panthor_hw_init on a GPU still held in reset -- and each cost a physical
      # power-cycle to recover. As a module it can be blacklisted at boot and
      # insmod'd over SSH, so a fault at probe leaves the machine reachable.
      # Blacklist lives in hardware-configuration.nix; drop it once proven.
      #
      # SOC_SKY1 selects sky1/sky1.c, whose non-ACPI branch attaches
      # pd_core0/1/2 and the "perf" domain by name -- the shape of the DT node
      # added below.
      #
      # Both V3 and V3_1 architectures are built in, because the ISA version is
      # read from the hardware at probe, not declared in the DT -- the node's
      # compatible is the generic "armchina,zhouyi". aipu_priv.c dispatches on
      # that value against whichever handlers were compiled in, and falls over
      # if the matching one is absent:
      #
      #   armchina 14260000.aipu: unidentified hardware version number: 5
      #   armchina 14260000.aipu: aipu real probe failed, ret: -22
      #
      # 5 is AIPU_ISA_VERSION_ZHOUYI_V3. This silicon reports V3, not the V3_1
      # its marketing generation would suggest, so V3 is the one that actually
      # matters here; V3_1 is kept because it costs one object file and removes
      # a class of surprise if a later board revision reports 6. Corroborated by
      # the DT node itself: cluster-partition is parsed by v3_priv.c.
      ./scripts/config --module ARMCHINA_NPU
      ./scripts/config --enable ARMCHINA_NPU_ARCH_V3
      ./scripts/config --enable ARMCHINA_NPU_ARCH_V3_1
      ./scripts/config --enable ARMCHINA_NPU_SOC_SKY1
      # sky1.c guards its devfreq code on CONFIG_ENABLE_DEVFREQ, which the
      # driver's Makefile defines from CONFIG_PM_DEVFREQ.
      ./scripts/config --enable PM_DEVFREQ

      # ── USB (04-usb-phy-typec) ──────────────────────────────────────────────
      # The controllers are Cadence USBSSP behind a CIX wrapper, so the stack is
      # USB_CDNS_SUPPORT -> USB_CDNSP -> USB_CDNSP_SKY1, plus the CIX PHYs.
      #
      # cdnsp-sky1 is a MODULE on purpose. Built in, it hung the machine solid
      # during boot -- an unrecoverable CPU lockup, screen stuck on:
      #
      #   Sending NMI from CPU 0 to CPUs 7:
      #   NMI backtrace for cpu 7 skipped
      #
      # and only a physical power cycle and a menu pick got the board back. The
      # reasoning for building it in (a keyboard has to exist early enough to
      # rescue a bad boot) was sound but backwards in sequencing: it removed the
      # ability to iterate at exactly the point where six brand-new controllers
      # probe for the first time. The NPU pattern is the right one -- module,
      # blacklisted, insmod over SSH -- and it goes back to =y only once every
      # controller has probed cleanly at least once.
      #
      # xHCI and HID stay built in; they are mainline code that already works,
      # and nothing binds to them until the platform glue is loaded.
      ./scripts/config --enable USB_SUPPORT
      ./scripts/config --enable USB
      ./scripts/config --enable USB_XHCI_HCD
      ./scripts/config --enable USB_XHCI_PLATFORM
      ./scripts/config --enable USB_CDNS_SUPPORT
      ./scripts/config --enable USB_CDNS_HOST
      # USB_CDNS3 must be =y even though this board uses the USBSSP (cdnsp)
      # controller rather than USBSS (cdns3). 04 inserts its USB_CDNSP symbol
      # INSIDE mainline's "if USB_CDNS3 ... endif # USB_CDNS3" block, so
      # USB_CDNSP inherits that dependency and is capped by it. USB_CDNS3
      # defaults to m, which silently capped USB_CDNSP at m no matter what
      # scripts/config said, and the build then reported "LD [M]":
      #
      #   FATAL: CONFIG_USB_CDNSP must be built in (=y), not a module.
      #
      # USB_CDNS3_HOST is the xHCI half; it is bool and needs USB=y.
      ./scripts/config --enable USB_CDNS3
      ./scripts/config --enable USB_CDNS3_HOST
      ./scripts/config --enable USB_CDNSP
      ./scripts/config --module USB_CDNSP_SKY1
      # CIX PHYs: without these the usbss controllers get -EPROBE_DEFER forever
      # on their phys phandle and never bind.
      ./scripts/config --enable GENERIC_PHY
      # The PHY symbols are bool and named per-block; there is no umbrella
      # PHY_CIX. USBDP is needed even though DP alt-mode is not enabled,
      # because it owns the USB3 lanes on the Type-C ports.
      ./scripts/config --enable PHY_CIX_USB2
      ./scripts/config --enable PHY_CIX_USB3
      ./scripts/config --enable PHY_CIX_USBDP
      # TYPEC is required even though Type-C alt-mode and PD are NOT enabled.
      # phy-cix-usbdp.c registers itself as a Type-C mux and orientation switch
      # unconditionally in cix_udphy_probe(), so without it the kernel does not
      # link:
      #   phy-cix-usbdp.o: undefined reference to `typec_switch_register'
      #   phy-cix-usbdp.o: undefined reference to `typec_mux_register'
      # =y rather than =m because PHY_CIX_USBDP is bool, i.e. built in, and a
      # built-in object cannot resolve symbols from a module.
      # Input devices, so a keyboard is actually usable once enumerated.
      ./scripts/config --enable HID
      ./scripts/config --enable HID_GENERIC
      ./scripts/config --enable USB_HID
      ./scripts/config --enable INPUT_EVDEV
      ./scripts/config --enable TYPEC
      ./scripts/config --enable USB_STORAGE

      # ── Phase 3: console and diagnostics ────────────────────────────────────
      ./scripts/config --enable SERIAL_AMBA_PL011
      ./scripts/config --enable SERIAL_AMBA_PL011_CONSOLE
      ./scripts/config --enable EFI
      ./scripts/config --enable EFI_STUB
      ./scripts/config --enable EFI_EARLYCON
      # ── Display: give the compositor a KMS device ───────────────────────
      # panthor is render-only -- card0 has zero connectors and no CRTC -- and
      # the Sky1 display controller driver is not ported, so without this there
      # is NO KMS device on the machine at all. greetd starts, the login is
      # accepted (pam opens the session), and then the compositor exits because
      # it has nothing to drive. On screen that is a blinking cursor.
      #
      # The framebuffer itself works; it was just claimed by the wrong driver:
      #
      #   efifb: mode is 1920x1080x32
      #   fb0: EFI VGA frame buffer device      <- legacy fbdev, not DRM
      #
      # sysfb hands the EFI GOP to either a legacy "efi-framebuffer" device or a
      # "simple-framebuffer" one, and that choice is SYSFB_SIMPLEFB. It was not
      # set, so efifb won and simpledrm (=m) never had a device to bind to.
      # Select simple-framebuffer, build simpledrm in, and drop FB_EFI so the
      # two cannot race for the same memory.
      #
      # This is unaccelerated scanout of the firmware framebuffer, not the real
      # display pipeline -- 1920x1080 fixed, no mode setting. It is enough for a
      # desktop to appear and be looked at. The proper fix is porting
      # 05-display-drm-cix, at which point this becomes a fallback.
      ./scripts/config --enable SYSFB
      ./scripts/config --enable SYSFB_SIMPLEFB
      ./scripts/config --enable DRM_SIMPLEDRM
      ./scripts/config --disable FB_EFI
      ./scripts/config --enable DRM_FBDEV_EMULATION
      ./scripts/config --enable FRAMEBUFFER_CONSOLE

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

      # USB must be built in too. It is how this machine is driven from the
      # console, and a keyboard that only appears after /nix has been read is
      # no use for rescuing a bad boot. Asserted rather than assumed because
      # "scripts/config --enable" on a tristate silently yields =m when a
      # dependency is itself modular, and the first USB build did exactly
      # that -- kbuild reported "LD [M] cdnsp-sky1.o".
      USB_BUILTIN="USB USB_XHCI_HCD USB_XHCI_PLATFORM USB_CDNS_SUPPORT"
      USB_BUILTIN="$USB_BUILTIN USB_CDNS3 USB_CDNSP TYPEC"
      USB_BUILTIN="$USB_BUILTIN PHY_CIX_USB2 PHY_CIX_USB3 PHY_CIX_USBDP"
      USB_BUILTIN="$USB_BUILTIN USB_HID HID_GENERIC INPUT_EVDEV"
      # simpledrm must be built in and must own the framebuffer, or there is no
      # KMS device and no desktop.
      USB_BUILTIN="$USB_BUILTIN DRM_SIMPLEDRM SYSFB_SIMPLEFB"
      for opt in $USB_BUILTIN; do
        if ! grep -q "CONFIG_''${opt}=y" .config; then
          echo "FATAL: CONFIG_''${opt} must be built in (=y), not a module." >&2
          grep "CONFIG_''${opt}" .config >&2 || echo "  (absent from .config)" >&2
          exit 1
        fi
      done
      # The inverse assertion: cdnsp-sky1 must NOT be built in. Being wrong
      # here costs a physical power cycle, so it is worth a gate of its own.
      if ! grep -q "CONFIG_USB_CDNSP_SKY1=m" .config; then
        echo "FATAL: CONFIG_USB_CDNSP_SKY1 must be a module (=m) until the" >&2
        echo "       USB controllers have probed cleanly at least once." >&2
        grep "CONFIG_USB_CDNSP_SKY1" .config >&2 || echo "  (absent)" >&2
        exit 1
      fi
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
