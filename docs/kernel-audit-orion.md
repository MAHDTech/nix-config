# Kernel Audit: Orion (CIX Orion O6)

## 1. Current Kernel Status

The `orion` host **does not** track the default NixOS stable kernel. Instead, it builds a **custom patched mainline kernel** from a dynamic configuration.

**Version & Patches applied:**

- **Base Version**: `6.19.14` (Source fetched from `https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.19.14.tar.xz`).
- **Patches**: It applies out-of-tree hardware enablement patches from the
  `Sky1-Linux/linux-sky1` GitHub repository (pinned to commit `57e018a...`). It
  specifically patches sequentially from `patches-latest/*.patch` and injects
  a custom rebased audio patch:
  `0056-ASoC-ALSA-CIX-Sky1-audio-fixes-6.19.14.patch`.
- **Configurations**:
  - Builds with `-march=armv8-a+crypto`.
  - Uses the official Sky1 defconfig (`config.sky1-latest`) combined with many NixOS-specific overrides.
  - _Enabled Features:_ `DRM_SIMPLEDRM`, strict devmem (`STRICT_DEVMEM`),
    built-in NVMe (`BLK_DEV_NVME`) for early boot root mount, persistent crash
    capture (`PSTORE`), ZRAM swap with ZSTD backend, AppArmor, and BTRFS crypto
    dependencies.
  - _Optimizations:_ Disables irrelevant debug symbols, AMD/Nouveau/Radeon DRM drivers, and irrelevant SoC architectures (Qualcomm, Tegra, Rockchip) to vastly reduce compile time.

## 2. Key Hardware of the Host

- **SoC:** CIX Orion O6 / Sky1 (ARM64 architecture).
- **GPU:** Immortalis-G720 MC10 GPU (CSF-based, driven by the `panthor` driver; `panfrost` is explicitly blacklisted).
- **NPU & VPU:** CIX NPU (`aipu` driver) and CIX VPU (`amvx` driver).
- **Audio DSP:** Tensilica HiFi5 (`CIX_DSP`).
- **Networking:** Realtek RTL8126 (5GbE) and RTL8125 (2.5GbE) controllers.
- **USB/Display:** Cadence PCIe-attached USB controllers (`cdns3`/`cdnsp`), CIX Display controller (`linlon-dp`), CIX DisplayPort subsystem, and USB-C PD with DisplayPort Alt Mode.

## 3. Linux Kernel 7.1.1 Impact & Changes

### Improvements to Expect:

- **Upstreamed CIX/Sky1 Support:** The 7.1 cycle officially merged support for
  the CIX P1/CD8180 (Sky1) platform. This includes device tree additions
  (`cix,sky1`), clock/reset support, mailbox driver updates, and the
  Cadence-Sky1 PCI controller.
- **Panthor `OP_MAP_REPEAT`:** Adrián Larumbe's `OP_MAP_REPEAT` patches for Panthor were merged, solving major performance and stability issues with Vulkan sparse resources on Immortalis-G720 GPUs.
- **Arm64 Hardware Errata Mitigation:** Mitigates CVE-2025-10263 (a TLB Invalidation defect) for ARM CPUs.
- **Networking Stability:** A network signaling deadlock under heavy traffic was fixed by transitioning to RCU locking.

### What Might Break:

- The out-of-tree NPU (`aipu`) and VPU (`amvx`) drivers may fail to build against the new 7.1.1 kernel APIs, requiring updates from CIX or community maintainers.
- Upstreamed CIX device tree and driver names might slightly differ from the downstream Sky1 patches, which could break current udev rules or sysctl configurations.

### Required Nix Config Changes for Upgrading to 7.1.1:

1.  **Drop Upstreamed Patches:** Remove or vastly trim the `sky1Patches`
    repository checkout and the `prePatch` loop in
    `hardware/kernel/default.nix`, since CIX/Sky1 and Cadence PHY support are
    now mainline.
2.  **Remove PanVK Workarounds:** In `default.nix`, you can now safely remove the `VK_ICD_FILENAMES=""` environment override for Wayland services (like `hypridle` and `swaync`).
3.  **Adjust Validation Gates:** Check if mainline Kconfig names match the custom downstream ones (e.g., `CONFIG_DRM_CIX` or `CONFIG_PHY_CIX_USBDP`).
