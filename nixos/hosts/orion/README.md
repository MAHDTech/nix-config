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
  - **Details**: CSF-based GPU driver loaded successfully. Legacy `panfrost` driver is blacklisted to prevent conflicts.
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
  - **Linux Driver**: `r8169`
  - **Status**: ✅ Working
  - **Details**: Both ethernet controllers probe and run at full speed.
- **WiFi & Bluetooth**
  - **Hardware Spec**: Intel AX210 (M.2 Key-E)
  - **Linux Driver**: `iwlwifi` & `btintel`
  - **Status**: ✅ Working
  - **Details**: Fully operational with standard `linux-firmware` blobs.
- **NPU & VPU**
  - **Hardware Spec**: CIX NPU / VPU Accelerator
  - **Linux Driver**: `aipu` & `amvx`
  - **Status**: ✅ Working
  - **Details**: Loaded cleanly via out-of-tree kernel modules.
- **TPM 2.0**
  - **Hardware Spec**: Discrete TPM Header
  - **Linux Driver**: None
  - **Status**: ❌ Not Supported
  - **Details**: Hardware TPM chip is unsoldered on this board. UEFI firmware currently lacks fTPM support.
- **Type-C UCSI**
  - **Hardware Spec**: Hardware-managed Alt-mode
  - **Linux Driver**: None
  - **Status**: ❌ Not Supported
  - **Details**: UCSI interface is not defined in ACPI; Alt-mode and PD routing are handled directly in hardware/firmware.
- **Native Display (Linlon/Trilinear DP)**
  - **Hardware Spec**: CIX Display Controller + DisplayPort
  - **Linux Driver**: `linlon-dp`, `trilin-dpsub`
  - **Status**: ⚠️ Partially Working
  - **Details**: Display works via `simpledrm` EFI framebuffer fallback. Native CIX
    display drivers (`DRM_CIX`, `DRM_LINLONDP`, `DRM_TRILIN_DPSUB`) were being silently
    dropped by `make olddefconfig` during kernel build. Fix applied in `kernel.nix`
    (configurePhase restructuring) — pending rebuild and verification.

---

## 2. Active Software Workarounds & Hacks

Due to the pre-production/early-stage nature of the CIX P1 UEFI firmware and kernel patches, several workarounds are in place:

### 1. SMMUv3 Bypass (Kernel-Level)

- **Location**: `kernel.nix` (kernel config) and `hardware/hardware-configuration.nix` (kernel params)
- **Mechanism**: Two-pronged kernel-level bypass:
  1. Kernel config: `CONFIG_ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT` disabled (allows unmapped DMA streams)
  2. Kernel param: `arm-smmu-v3.disable_bypass=0` (runtime bypass)
- **Why**: The EDK2 BIOS v1.2.1 has an invalid IORT table that misconfigures the SMMUv3
  Stream ID mappings. Without bypass, SMMU event queue interrupts trigger an interrupt
  storm, causing `CMD_SYNC` timeouts on the NVMe controller, filesystem crashes, and
  kernel panics.
- **History**: Previously used a userspace `devmem2` workaround (`hardware/smmu-fix.nix`)
  which required disabling `STRICT_DEVMEM`. That approach was removed in favour of the
  cleaner kernel-level bypass. `STRICT_DEVMEM` and `IO_STRICT_DEVMEM` are now re-enabled
  for security.

### 2. Clock Termination Protection (`clk_ignore_unused`)

- **Location**: `hardware/hardware-configuration.nix` (under `boot.kernelParams`)
- **Mechanism**: Kernel boot parameter `clk_ignore_unused`.
- **Why**: Prevents the generic Linux clock subsystem from disabling unused clocks initialized by UEFI before CIX-specific drivers have finished probing and claiming them.

### 3. GPU Driver Blacklisting (`module_blacklist=panfrost`)

- **Location**: `hardware/hardware-configuration.nix` (under `boot.kernelParams`)
- **Mechanism**: Explicitly blacklists the legacy `panfrost` module.
- **Why**: Prevents the kernel from trying to bind the legacy Mali `panfrost` driver to the Immortalis-G720 GPU, ensuring `panthor` takes sole control.

---

## 3. Known Issues

### 1. Voltage Regulator Probe Failures (ENOMEM)

- **Severity**: ⚠️ Moderate (non-blocking)
- **Symptom**: 11 fixed-voltage regulators fail to probe with error -12 (ENOMEM) at boot:
  - `CPE4`, `PVC0`–`PVC4`, `VWL0`, `VBT0`, `VUS0`, `VUS4`, `VUS5`
- **Root Cause**: These are ACPI-defined power rails (`PRP0001` nodes with
  `compatible = "regulator-fixed"`) probed by our `fixed-regulator-acpi.patch`.
  The -12 error is likely not a genuine OOM (62GB RAM at t=0.17s) but rather propagated
  from `regulator_register()` failing due to incomplete ACPI regulator properties
  (missing GPIO/enable pin configs).
- **Impact**: Hardware works — these are likely always-on power rails. May affect future suspend/resume power management.
- **Investigation**: Enable `CONFIG_REGULATOR_DEBUG=y` to get detailed probe logs. Compare with Ubuntu CIX kernel's regulator handling.

### 2. ACPI Thermal — No Valid Trip Points

- **Severity**: ⚠️ Moderate
- **Symptom**: `[Firmware Bug]: No valid trip points!` — ACPI thermal zones report temperatures but have no throttle/shutdown thresholds.
- **Impact**: Kernel cannot automatically throttle or shutdown on overheating via ACPI. SCMI thermal may partially cover this. Idle temps are normal (49–67°C).
- **Waiting On**: BIOS update from Radxa with valid thermal trip point definitions.

### 3. ramoops Probe Failure

- **Severity**: 🟢 Low
- **Symptom**: `ramoops PRP0001:03: probe failed with error -22 (EINVAL)` — ACPI node `\_SB_.RAOP` defines ramoops but with invalid platform data parameters.
- **Impact**: Kernel crash dump logging to persistent RAM is non-functional. Crashes leave no pstore record.
- **Waiting On**: BIOS update with corrected ramoops ACPI parameters.

### 4. Boot Timing — Network Wait (10s)

- **Severity**: 🟢 Low
- **Symptom**: `systemd-networkd-wait-online.service` adds ~10s to boot waiting for all configured interfaces.
- **Root Cause**: Two unconnected NICs (`enu1u2u4` USB Ethernet, `enp49s0` 2nd 5GbE) are configured but have no carrier.
- **Fix**: Set `RequiredForOnline=no` for unused interfaces or narrow the wait-online scope.

### 5. `suspend-on-low-battery.timer` Error

- **Severity**: 🟢 Low (cosmetic)
- **Symptom**: Timer refuses to start — trigger unit `suspend-on-low-battery.service` not loaded.
- **Root Cause**: Desktop NixOS module defines a battery suspend timer; Orion O6 has no battery.
- **Fix**: Disable the timer if possible, or ignore.

---

## 4. What We Are Waiting On

We are tracking the following upstream development items and firmware updates:

1. **BIOS Fix for SMMU (Radxa / CIXTech)**:
   - **Waiting For**: An updated EDK2 BIOS/UEFI firmware release containing a corrected ACPI IORT table.
   - **Action Item**: Once this is released, we can remove the kernel-level SMMU bypass (`ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT` and `arm-smmu-v3.disable_bypass=0` kernel param).
2. **HDMI/DisplayPort Audio Drivers (CIXTech)**:
   - **Waiting For**: Upstreaming of the Tensilica HiFi5 DSP IPC / Mailbox controller driver (`SND_HDA_CIX_IPBLOQ`) and corresponding firmware release to `cix-linux-main`.
   - **Action Item**: Once the code lands and audio firmware is provided, we will update the config to pull the new firmware package and load the DSP kernel module.
3. **TPM Support**:
   - **Waiting For**: Either a firmware-based TPM (fTPM) option inside the UEFI / OP-TEE secure world, or manual soldering of an SPI TPM 2.0 chip to the motherboard's open TPM header.
4. **BIOS Fix for ACPI Thermal Trip Points (Radxa / CIXTech)**:
   - **Waiting For**: Corrected ACPI thermal zone definitions with valid trip points for throttle/critical temperatures.
5. **BIOS Fix for ramoops (Radxa / CIXTech)**:
   - **Waiting For**: Corrected ACPI `\_SB_.RAOP` node parameters for persistent RAM crash logging.

---

## 5. Task Tracker (Across Sessions)

### Completed

- [x] Investigate early-boot NVMe timeout crash of Generation 37 (Root cause: SMMUv3 event storm triggered by display driver DMA before systemd service runs)
- [x] Shift SMMU event queue workaround into stage-1 initrd (`boot.initrd.systemd.services`)
- [x] Trigger deployment of Generation 38 (Failed to boot due to missing initrd script package)
- [x] Investigate boot failure of Generation 38 (Root cause: initrd script not in boot.initrd.systemd.storePaths)
- [x] Add initrd script to boot.initrd.systemd.storePaths
- [x] Verify NixOS configuration syntax and build ORION system configuration (Generation 32 built with modular display drivers, early stage-2 workaround, and deadlock-breaking dependencies)
- [x] Remove userspace SMMU workaround (`smmu-fix.nix`) — replaced with kernel-level bypass (commit `a168ba2`)
- [x] Re-enable `CONFIG_STRICT_DEVMEM` and `CONFIG_IO_STRICT_DEVMEM` (done in `kernel.nix`)
- [x] Deploy Generation 33 — booted successfully via SSH

### In Progress

- [/] Fix `make olddefconfig` silently dropping CIX kernel config options (17+ options
  affected: display, PHY, USB, PWM). Root cause: `scripts/config` edits placed
  before `olddefconfig` in `kernel.nix` configurePhase. Fix: restructured
  configurePhase to place all edits after `olddefconfig` with validation gate.
  - [x] Diagnose root cause (audit session 2026-06-04)
  - [x] Implement fix in `kernel.nix`
  - [ ] Rebuild kernel and deploy
  - [ ] Verify CIX display modules (`linlon-dp`, `trilin-dpsub`) load on boot
  - [ ] Verify native display output (not simpledrm fallback)

### Pending

- [ ] Investigate voltage regulator probe failures (11 regulators, error -12) — enable `CONFIG_REGULATOR_DEBUG=y` and compare with Ubuntu CIX kernel
- [ ] Investigate boot timing — reduce `systemd-networkd-wait-online` 10s delay
- [ ] Housekeeping: run `nix-collect-garbage`, configure `boot.loader.systemd-boot.configurationLimit` to auto-prune old generations
- [ ] Trim `orion.defconfig` — remove irrelevant SoC platform drivers (Qualcomm, Tegra, Rockchip, etc.) to reduce compile time
