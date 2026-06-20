# Kernel Audit: Zenbook (ASUS Zenbook S 15)

## 1. Current Kernel Usage

The host does **not** track the default NixOS stable kernel (`pkgs.linuxPackages`). Instead, it uses a completely custom kernel derivation defined in `hardware/kernel.nix`.

## 2. Custom Kernel and Branch Details

### a. Current Kernel Version & Patches/Configs:

- **Version**: `7.1.0-rc7-next-20260611`. It currently tracks the `linux-next` branch (from `git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git`).
- **Patches**:
  - There are currently no active `.patch` files in `files/patches` (the Iris video codec patch `0018-WIP-arm64-dts-qcom-x1-asus-zenbook-a14-enable-Iris.patch` is disabled).
  - A runtime `sed` patch is applied to `drivers/gpu/drm/msm/Kconfig` to forcibly select `DRM_SYNCOBJ`
    and `DRM_SYNCOBJ_TIMELINE_EXPORT` (which resolves a known Vulkan rendering hang/crash documented
    as Issue 1).
- **Configurations**:
  - Uses an automated hardware profile (`zenbook.defconfig`).
  - Extensively modifies Kconfig via `scripts/config` to manually enable critical Snapdragon
    components that often cascade-fail in default configs: Qualcomm IPC/Mailbox, SCMI power domains,
    POWERCAP (critical for PMIC overcurrent protection), TPM 2.0 (fTPM), Limits Management Hardware
    (LMH) for thermal throttling, and forces DRM panel drivers to be built-in (`=y`) for early display.
  - Blacklists several audio modules (`snd_soc_wsa884x`, `snd_soc_x1e80100`, etc.) in
    `hardware-configuration.nix` due to a known issue (Issue 22) where audio playback causes
    an instant PMIC hardware reset.

### b. Key Hardware of this Host:

- **SoC**: Qualcomm Snapdragon X Elite (Platform `X1E80100`).
- **Device**: ASUS Zenbook S 15 (`zenbook-a14` / `UX3407RA`).
- **Architecture**: `aarch64` / `arm64`.
- **GPU**: Adreno X1-85.

## 3. Linux Kernel 7.1.1 Impact & Changes

### Improvements to Expect:

Upstream improvements to Arm-based platform standardization, X1E80100 power management (DCVS), and GPU/CPU performance scaling should result in better battery life and sustained performance.

### What Might Break / Config Changes Needed:

- **Move off `linux-next`**: We need to update `kernel.nix` to pull from the stable `linux-7.1.1` tarball/git tag rather than relying on `next-20260611`.
- **Drop `DRM_SYNCOBJ` Patch**: The local `sed` patch injecting `DRM_SYNCOBJ` into `DRM_MSM` might conflict
  or become redundant if the `msm` DRM driver has properly declared these dependencies in the 7.1
  stable branch.
- **Re-evaluate Audio Workarounds (Issue 22)**: The audio playback PMIC hard reset could be addressed by
  power sequencing / SoundWire fixes upstream in 7.1.1. We should test un-blacklisting the `snd_soc_*`
  and `soundwire_qcom` modules. Additionally, the `i_accept_the_danger` parameter handling changed
  upstream; if we still need a workaround, we will likely need to pass it via the kernel cmdline
  (`snd-soc-x1e80100.i_accept_the_danger=1`) rather than `extraModprobeConfig`.
- **Re-evaluate SCMI / POWERCAP config flags**: Since 7.1.1 contains mature X1E80100 power management,
  some of the manual `scripts/config --enable POWERCAP` flags may now be present in the default arm64
  defconfig and can be cleaned up.
- **Thunderbolt / USB4**: As per `ISSUES.md`, the platform driver for the non-PCIe USB4 Host Router
  (`qcom,usb4-hr`) is not expected to be mainline until 7.2+, so Thunderbolt 5 dock functionality
  (Issue 16) will likely still require our USB 2.0 fallback or an external adapter even on 7.1.1.
