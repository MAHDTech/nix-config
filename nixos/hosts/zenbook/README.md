# ASUS Zenbook A14 — NixOS Issue Tracker

> Snapdragon X Elite (X1E80100 / UX3407RA) · Adreno X1-85 · aarch64
> Kernel: linux-next `next-20260528` · Mesa 26.1.1 (freedreno) · NixOS 26.05

---

## Active Status & Task Tracker

- 🔴 **Issue 20**: [PMIC Hard Reset on Every NixOS Boot](#issue-20-pmic-hard-reset-on-every-nixos-boot-systematic-debug-2026-06-11) (P0)
  — _Fix Deployed & Testing on Gen 32; verifying Stage 1 firmware load._
- 🟡 **Issue 3**: [GPU frequency hard-capped at 390 MHz](#issue-3-gpu-frequency-hard-capped-at-390-mhz) (P1) — _Regression; GPU uncapped in default boot, but `power-safe` cap fallback is set up._
- 🟡 **Issue 5**: [pstore/ramoops not configured for crash debugging](#issue-5-pstore-ramoops-not-configured-for-crash-debugging) (P0)
  — _Ramoops overlay disabled temporarily for debugging; `pstore-blk` label fixed._
- 🟡 **Issue 7**: [DSP subsystem (qcom_q6v5_pas) enablement](#issue-7-dsp-subsystem-qcom_q6v5_pas-enablement) (P3) — _Late-load crash analyzed; Stage 1 firmware fix deployed in Gen 32._
- 🟡 **Issue 16**: [Thunderbolt 5 dock drops to USB 2.0 full-speed](#issue-16-thunderbolt-5-dock-drops-to-usb-2-0-full-speed) (P1) — _Blocked on upstream kernel patches for non-PCIe host routers._
- 🟡 **Issue 18**: [pmic_glink uevent failures & battery notifier](#issue-18-pmic_glink-uevent-failures) (P3)
  — _Open; battery telemetry works via sysfs but battery notifier requires a device override._

> [!NOTE]
> All **fully resolved issues** (Issues 1, 2, 4, 6, 8, 9, 10, 11, 12, 13, 14,
> 15, and 17) have been archived in [resolved_issues.md](file:///boot/nixos/nix-config/nixos/hosts/zenbook/resolved_issues.md)
> to keep this main issue tracker focused and actionable.

---

## Open & In-Progress Issues

### Issue 3: GPU frequency hard-capped at 390 MHz

- [ ] **Status**: Regression in Gen 2. Removing the cap allowed the GPU to reach `1.25 GHz` but caused an instant PMIC overcurrent hard reboot under Vulkan load (`vkmark`).
- **Severity**: P1 — GPU at ~31% max performance.
- **Symptom**: `cat /sys/class/devfreq/3d00000.gpu/max_freq` → `390000000` (when capped).
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (cap removal in default configuration)
  - `nixos/hosts/zenbook/kernel.nix` (enabling `POWERCAP`, `ARM_SCMI_POWERCAP`, and `QCOM_LMH`)

* **Root Cause & Fix Strategy**:
  - On the Snapdragon X Elite, GPU voltage and frequency scaling (DVFS) are
    managed autonomously in hardware by the **GMU (Graphics Management Unit)**
    firmware and **RPMh (Resource Power Manager Hardened)**.
  - System resets under uncapped GPU load were due to the lack of active
    **limits management (Qualcomm LMH)** and **SCMI power limits** in the Linux
    configuration. Without these limits (which are handled in Windows by the
    PEP/ACPI framework), the hardware draws current spikes that exceed the PMIC
    physical envelope, triggering instantaneous overcurrent shutdown.
  - **Fix**: Enforced `ARM_SCMI_POWERCAP` and `QCOM_LMH` in the kernel config to allow firmware power throttling.
  - **Rollback Safety**: A `power-safe` specialisation exists as a rollback safety net to restore a conservative 390 MHz cap via a udev rule if instability returns:
    ```nix
    specialisation."power-safe".configuration = {
      services.udev.extraRules = ''
        SUBSYSTEM=="devfreq", KERNEL=="3d00000.gpu", ACTION=="add", ATTR{max_freq}="390000000"
      '';
    };
    ```

---

### Issue 5: pstore/ramoops not configured for crash debugging

- [/] **Status**: Partially verified on Gen 6.
  - ✅ **ramoops**: `pstore: Registered ramoops as persistent store backend` using `0x200000@0xb7000000, ecc: 0` (no ECC errors).
  - ✅ **netconsole**: systemd service `active (exited)` configured with JONS destination (`10.10.1.90 → 10.10.1.93:6666`).
  - ⚠️ **pstore-blk**: partition exists (`disk-main-pstore`, 16M) but kernel param label corrected in Gen 32 from `/dev/disk/by-partlabel/pstore` to `/dev/disk/by-partlabel/disk-main-pstore`.
  - ❌ **pstore dir**: empty (no crashes yet — expected).
- **Severity**: P0 — No crash dumps captured on any crash type.
- **Codebase References**:
  - `nixos/hosts/zenbook/disko-config.nix` (16M `pstore` partition)
  - `nixos/hosts/zenbook/files/ramoops-overlay.dts` (Device tree reservation)
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (`panic` settings, sysctl, and overlay integration)

* **Root Cause & Fix Strategy**:
  - ARM64 ignores the standard `memmap=` kernel boot arguments, requiring a
    Device Tree overlay (`ramoops-overlay.dts`) to reserve memory (`2MB` at
    `0xb7000000` with `no-map`).
  - **Current State**: The `ramoops-overlay` was temporarily disabled in
    `hardware-configuration.nix` (`deviceTree.overlays = [ ]`) to isolate a
    boot-loop regression. Once Stage 1 boot stability is verified, this
    overlay must be re-enabled.

- **Crash capture layers** (defense in depth):
  - **DTB ramoops (2MB reserved)**: Captures panics (✅), captures PMIC resets (❌). Status: ✅ _Verified Gen 6 (ecc: 0, no errors)._
  - **Panic escalation settings**: Captures panics (✅, enables flush), captures PMIC resets (❌). Status: ✅ _Verified Gen 6 (kernel params confirmed)._
  - **Netconsole → JONS:6666**: Captures panics (✅, live), captures PMIC resets (⚠️ Pre-crash only). Status: ✅ _Verified Gen 6 (systemd service active, logging started)._
  - **pstore-blk (NVMe partition)**: Captures panics (✅), captures PMIC resets (⚠️ Maybe). Status: ⚠️ _Partition exists, label fix pending rebuild._

---

### Issue 7: DSP subsystem (qcom_q6v5_pas) enablement

- [/] **Status**: Blocked
  - **Workaround Active**: ADSP is blacklisted globally in the `no-adsp` and `power-safe` specialisations to force the TB5 dock into stable USB 2.0 fallback, avoiding Alt Mode lockups.
  - This disables native audio and battery telemetry as a necessary tradeoff for stable network connectivity.
- **Severity**: P3 — Future improvement.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix`
    (ADSP/CDSP firmware paths and modprobe ordering)
  - `nixos/hosts/zenbook/hardware/pd-mapper.nix` (`pd-mapper` daemon with ConditionPath guards)

* **Root Cause & Fix Strategy**:
  - Previously, starting the DSP caused NVMe/PCIe power domain/SMMU conflicts.
  - The Stage 1 initrd firmware bug (documented in Issue 20) caused the DSP to load late in Stage 2, triggering SoundWire timeouts and PMIC resets. The Stage 1 fix has been deployed in Gen 32.

---

### Issue 16: Thunderbolt 5 dock drops to USB 2.0 full-speed

- [/] **Status**: Blocked on upstream kernel patches.
- **Severity**: P1 — No dock ethernet, no DP alt-mode.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix`
    (Type-C/Alt Mode available kernel modules loaded in Stage 1)
  - `nixos/hosts/zenbook/kernel.nix` (`CONFIG_UCSI_PMIC_GLINK`,
    `CONFIG_TYPEC_DP_ALTMODE`, and `CONFIG_USB4` enabled)

* **Root Cause**:
  - Native USB4/Thunderbolt 5 tunneling is currently blocked. The Linux
    `thunderbolt` subsystem assumes all Host Routers are PCIe devices, but on
    the Snapdragon X Elite, the Host Router is integrated as a platform device.
  - Because the Host Router fails to bind (due to missing device tree bindings
    like `qcom,x1e80100-usb4-hr` in mainline), the dock eventually times out
    during Alt Mode negotiation and drops back to USB 2.0 Billboard fallback
    mode (480 Mbps).
  - **Workaround**: We use a dedicated USB-to-Ethernet adapter (`usb-to-eth` at `10.10.1.90`) to maintain a reliable network link while testing.

---

### Issue 18: pmic_glink uevent failures & battery notifier

- [ ] **Status**: Open — battery status works, but low-battery notifier is broken.
- **Severity**: P3 — Low.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix`
    (firmware bindings for `battmgr.jsn`)
  - `nixos/system/config/hardware/laptop/battery/default.nix` (enabling `services.batteryNotifier`)

* **Root Cause & Fix**:
  - Synthetic uevent failures (`-11`) occur for `qcom-battmgr-*` during boot, but battery capacity/status is fully readable in sysfs at `/sys/class/power_supply/qcom-battmgr-bat/capacity`.
  - **The Bug**: `services.batteryNotifier` does not define `device`, defaulting
    to `"BAT0"`. Since the Qualcomm battery manager registers as
    `"qcom-battmgr-bat"`, the low-battery notifier script silently exits because
    it cannot find the sysfs path.
  - **Fix**: Add `services.batteryNotifier.device = "qcom-battmgr-bat";` to the Zenbook host configuration to restore the battery notifier service.

---

### Issue 20: PMIC Hard Reset on Every NixOS Boot (Systematic Debug — 2026-06-11)

- [/] **Status**: Fix Deployed & Testing — verifying Stage-1 initrd firmware inclusion
- **Severity**: P0 — System unusable, every boot crashes within <1 min.
- **Symptom**: Every installed NixOS generation (Gen 25–31) hard resets within 30–60 seconds of boot. The installer is completely stable.
- **Crash Signature**: The last kernel message before every crash is:
  ```
  regulator: Not disabling unused regulators
  ```
  The crash occurs ~15 seconds after `multi-user.target` is reached.
- **Root Cause & Resolution**:
  - **Nixpkgs initrd Firmware Bug**: The Stage 1 `initrd` built with
    `extraFirmwarePaths = [ "qcom" "ath12k" ];` completely omitted the `qcom`
    firmware. This is due to a Nixpkgs `modules-closure.sh` script bug where it
    invokes `cp` without a `-r` flag, silently failing to copy directory paths.
  - **Cascading Reset Trigger**: Because the ADSP firmware was missing, the
    `qcom_q6v5_pas` driver failed to load it in Stage 1 (`request_firmware
failed: -2`). Although the firmware successfully loaded late during Stage 2,
    this out-of-order load resulted in `qcom-apm` and SoundWire driver
    timeouts. When the kernel attempted deferred regulator cleanup (`regulator:
Not disabling unused regulators`), unclocked components triggered a Secure
    World (TrustZone) hardware panic and PMIC hard reset.
  - **Resolution (Gen 32)**: Listed the individual ADSP/CDSP firmware files in
    `boot.initrd.extraFirmwarePaths` in `hardware-configuration.nix` to bypass
    the `modules-closure.sh` copy limitation.
  - **Current State**: The fix is deployed and currently rebuilding natively on the target host via `nixos-anywhere` with `--build-on remote`.
