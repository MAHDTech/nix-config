# Kernel Audit: Bootycall (Ubiquiti CloudKey Gen2 Plus)

## 1. Current Kernel Configuration & Tracking

The host is **not** tracking the default Nix stable kernel (`pkgs.linuxPackages`). It is using a completely custom cross-compiled kernel defined in `hardware/kernel.nix`.

## 2. Custom Kernel Details

### a. Current kernel version and patches:

- **Version:** `7.0.9`
- **Source:** Custom branch `v7.0.9-r0` from the `msm8953-mainline/linux` community GitHub repository.
- **Configurations applied:** Starts from `allnoconfig` merged with a custom `cloudkey.config` fragment.
- **Patches applied in `kernel.nix`:**
  - Copies a custom device tree file (`cloudkey-mainline.dts`) into the kernel source at `arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dts`.
  - Modifies `arch/arm64/boot/dts/qcom/Makefile` to register this custom device tree.
  - Applies a "sledgehammer patch" to `drivers/pinctrl/qcom/pinctrl-msm.c`
    forcing the `msm_gpio_get_direction` function to instantly return
    `GPIO_LINE_DIRECTION_IN`.

### b. Key Hardware:

- Architecture: **aarch64** (Arm64).
- SoC: **Qualcomm APQ8053 / MSM8953** (Snapdragon 625 series).
- Device: **Ubiquiti CloudKey Gen2 Plus**.

## 3. Linux Kernel 7.1.1 Impact & Changes

### Improvements to Expect:

- **Hardware Security:** Since `bootycall` is an arm64 host, the 7.1.1 fix for
  the arm64 TLBI ordering defect (CVE-2025-10263) is highly relevant and
  improves the system's hardware security and stability.

### What Might Break / Compatibility:

- Linux 7.1 introduces standardized interfaces for Arm platforms, including
  SCMI GPIO. Because we currently have a very hacky "sledgehammer patch"
  injected into `pinctrl-msm.c` to manipulate GPIO directions, the 7.1
  infrastructure changes are highly likely to break this patch (either causing
  merge conflicts or changing the `msm_gpio_get_direction` implementation
  entirely).

### Required Nix Config Changes for 7.1.1 Upgrade:

- **Wait for Branch:** We will need to wait for the `msm8953-mainline` project to release a `v7.1.1` branch, as the mainline kernel still doesn't natively fully support this legacy SoC.
- **Update Sources:** Update `kernelVersion`, `rev`, and the source `hash` in `kernel.nix`.
- **Rewrite GPIO Patch:** Crucially, we will likely need to drop or rewrite the
  `sed` patch for `msm_gpio_get_direction`, as the 7.1 GPIO (SCMI)
  upstreaming may have either upstreamed the necessary fix natively or
  restructured the code such that our current `sed` command fails.
