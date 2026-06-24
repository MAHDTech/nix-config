# Kernel Audit: Bootycall (Ubiquiti CloudKey Gen2 Plus)

## 1. Current Kernel Configuration & Tracking

The host is **not** tracking the default Nix stable kernel (`pkgs.linuxPackages`). It is using
a completely custom cross-compiled kernel defined in
[kernel.nix](file:///boot/nixos/nix-config/nixos/hosts/bootycall/hardware/kernel.nix).

## 2. Custom Kernel Details

### a. Current kernel version and patches:

- **Version:** `7.1.1`
- **Source:** Mainline Linux stable tree (`https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.1.tar.xz`).
- **Configurations applied:** Compiled from `allnoconfig` merged with a minimal custom [cloudkey.config](file:///boot/nixos/nix-config/nixos/hosts/bootycall/files/cloudkey.config) fragment.
- **Patches applied in `kernel.nix`:**
  - Copies [cloudkey-mainline.dts](file:///boot/nixos/nix-config/nixos/hosts/bootycall/files/cloudkey-mainline.dts) into the kernel source at `arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dts`.
  - Modifies `arch/arm64/boot/dts/qcom/Makefile` to register this custom device tree.
  - Applies [0001-phy-qcom-qmp-usb-Add-msm8953-support.patch](file:///boot/nixos/nix-config/nixos/hosts/bootycall/patches/0001-phy-qcom-qmp-usb-Add-msm8953-support.patch)
    to `drivers/phy/qualcomm/phy-qcom-qmp-usb.c` to add USB 3.0 PHY support for `msm8953`.
- **Removed Patches:**
  - The legacy "sledgehammer patch" for `msm_gpio_get_direction` (which hardcoded pin directions) was dropped during the upgrade to 7.1.1. Native GPIO direction querying is now fully functional.

### b. Key Hardware & Subsystem Status:

- **Architecture:** `aarch64` (Arm64).
- **SoC:** Qualcomm APQ8053 / MSM8953 (8x Cortex-A53).
- **UART console:** Working (`ttyMSM0` console at `115200n8`).
- **eMMC:** Working via `sdhci_msm`.
- **USB Host & SATA SSD:** Working via `xhci-hcd` USB controller and `uas` driver for the ASMedia ASM1153 SATA bridge.
- **OLED Screen:** Working. Configured as module `fb_st7735r` using `ST7735R` display driver over SPI.
  Modprobing creates `/dev/fb0`. (We removed the blacklist since the udev hang was resolved by
  adding `buswidth = <8>` to the device tree).
- **RTC:** Working via SPMI `rtc-pm8xxx` driver.
- **Thermal:** Working via `qcom_tsens` driver.
- **Firewall/Netfilter:** Working. Required `CONFIG_NETFILTER` and `CONFIG_NF_TABLES` options are now built into the kernel config fragment to support NixOS `firewall.service`.
- **Battery/Power Supply Monitor:** Mainline lacks PMIC charging/battery driver support for the
  UCK-G2-Plus battery. `/sys/class/power_supply` is empty, and the graceful shutdown battery
  protection system is not monitored (acceptable as the battery is prone to swelling and is
  frequently removed).
