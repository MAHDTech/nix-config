# Radxa Orion O6 — NixOS Host Configuration & Hardware Status

This directory contains the NixOS host configuration for the Radxa Orion O6 board, powered by the CIX P1 (SKY1) 12-core Armv9.2 SoC.

---

## 1. Hardware Support & Status Matrix

- **USB-A & USB-C**
  - **Hardware Spec**: Generic USB Host Controller
  - **Linux Driver**: `xhci-hcd`
  - **Status**: ✅ Working
  - **Details**: Stable generic USB-A and USB-C ports. Powered peripherals (like ZSA Moonlander keyboard) are fully operational.
- **GPU**
  - **Hardware Spec**: Mali Immortalis-G720 MC10
  - **Linux Driver**: `panthor`
  - **Status**: ✅ Working
  - **Details**: CSF-based GPU driver loaded successfully via Device Tree. Legacy `panfrost` driver is blacklisted to prevent conflicts.
- **Audio (Analog)**
  - **Hardware Spec**: Realtek ALC256 Codec
  - **Linux Driver**: `cix-ipbloq-hda`
  - **Status**: ✅ Working
  - **Details**: Audio output and microphone capture via the 3.5mm headphone jack.
- **Audio (HDMI/DP)**
  - **Hardware Spec**: Tensilica HiFi5 DSP / Mailbox
  - **Linux Driver**: None
  - **Status**: ❌ Not Supported
  - **Details**: Missing upstream driver implementation.
- **Networking**
  - **Hardware Spec**: Dual Realtek RTL8126 5GbE
  - **Linux Driver**: `r8169` / natively patched
  - **Status**: ✅ Working
  - **Details**: Both ethernet controllers probe and run at full speed.
- **WiFi & Bluetooth**
  - **Hardware Spec**: Intel AX210 (M.2 Key-E)
  - **Linux Driver**: `iwlwifi` & `btintel`
  - **Status**: ✅ Working
  - **Details**: Fully operational with standard `linux-firmware` blobs.
- **NPU & VPU**
  - **Hardware Spec**: CIX NPU (Zhouyi) / VPU (Linlon MVE) Accelerator
  - **Linux Driver**: Native in-tree drivers
  - **Status**: ✅ Working
  - **Details**: Built directly into the kernel via `linux-sky1` patches. No DKMS required!
- **TPM 2.0**
  - **Hardware Spec**: Discrete TPM Header
  - **Linux Driver**: None
  - **Status**: ❌ Not Supported
  - **Details**: Hardware TPM chip is unsoldered on this board. UEFI firmware currently lacks fTPM support.
- **Native Display (Linlon/Trilinear DP)**
  - **Hardware Spec**: CIX Display Controller + DisplayPort
  - **Linux Driver**: `linlon-dp`, `trilin-dpsub`
  - **Status**: ✅ Working
  - **Details**: Fully operational. Drivers initialized natively via Device Tree.

---

## 2. Active Software Workarounds & Hacks

### 1. Clock Termination Protection (`clk_ignore_unused`)

- **Location**: `hardware/hardware-configuration.nix` (under `boot.kernelParams`)
- **Mechanism**: Kernel boot parameter `clk_ignore_unused`.
- **Why**: Prevents the generic Linux clock subsystem from disabling unused clocks initialized by UEFI before CIX-specific drivers have finished probing and claiming them.

### 2. GPU Driver Blacklisting (`module_blacklist=panfrost`)

- **Location**: `hardware/hardware-configuration.nix` (under `boot.kernelParams`)
- **Mechanism**: Explicitly blacklists the legacy `panfrost` module.
- **Why**: Prevents the kernel from trying to bind the legacy Mali `panfrost` driver to the Immortalis-G720 GPU, ensuring `panthor` takes sole control.

_(Note: The previous SMMU IORT bypass and `libdrm` ACPI hacks have been completely removed as they are obsolete under native Device Tree booting)._

---

## 3. Known Issues

### 1. Boot Timing — Network Wait (10s)

- **Severity**: 🟢 Low
- **Symptom**: `systemd-networkd-wait-online.service` adds ~10s to boot waiting for all configured interfaces.
- **Root Cause**: Two unconnected NICs (`enu1u2u4` USB Ethernet, `enp49s0` 2nd 5GbE) are configured but have no carrier.
- **Fix**: Set `RequiredForOnline=no` for unused interfaces or narrow the wait-online scope.

### 2. `suspend-on-low-battery.timer` Error

- **Severity**: 🟢 Low (cosmetic)
- **Symptom**: Timer refuses to start — trigger unit `suspend-on-low-battery.service` not loaded.
- **Root Cause**: Desktop NixOS module defines a battery suspend timer; Orion O6 has no battery.
- **Fix**: Disable the timer if possible, or ignore.

### 3. HDMI/DP Audio — ASoC ENODEV Errors

- **Severity**: Medium (no HDMI/DP audio output)
- **Symptom**: `hdmi-audio-codec hdmi-audio-codec.{0,1,2,4}: ASoC error (-19)` at boot on all HDMI/DP ports
- **Impact**: Audio output limited to Bluetooth. HDMI/DP audio non-functional.
- **Fix**: Waiting on CIX to upstream DSP/Audio drivers.

### 4. Display Flip Timeouts (Intermittent)

- **Severity**: Low-Medium (intermittent, can cause brief display freezes)
- **Symptom**: `linlondp CIXH5010:03: wait pipe0 flip done timeout` (3× at boot, occasional at runtime)
- **Mitigation**: `DRM_LINLONDP_CLOCK_FIXED` already enabled in kernel config.

---

## 4. What We Are Waiting On

1. **HDMI/DisplayPort Audio Drivers (CIXTech)**:
   - **Waiting For**: Upstreaming of the Tensilica HiFi5 DSP IPC / Mailbox controller driver (`SND_HDA_CIX_IPBLOQ`).
2. **TPM Support**:
   - **Waiting For**: Either a firmware-based TPM (fTPM) option inside the UEFI / OP-TEE secure world, or manual soldering of an SPI TPM 2.0 chip.

---

## 5. Task Tracker (Across Sessions)

### Completed

- [x] Migrate to `linux-sky1` patchset for in-tree NPU/VPU and native Device Tree support.
- [x] Remove obsolete DKMS packages and custom userspace patches.
- [x] Remove ACPI-specific `libdrm` overlay and restore binary caching for the graphics stack.
- [x] Repartition with 16MB raw pstore partition for persistent crash logging.
- [x] Deploy Generation 38+ (Successfully evaluated and rebuilt with `nixos-anywhere`).

### Pending

- [ ] Trim `config.sky1-next` kernel config to remove irrelevant SoC platform drivers (Qualcomm, Tegra, Rockchip) to reduce compile time.
- [ ] Investigate boot timing — reduce `systemd-networkd-wait-online` 10s delay.
- [ ] Investigate rtkit lacking RT capabilities — `Failed to make ourselves RT: Operation not permitted` affects PipeWire latency.
