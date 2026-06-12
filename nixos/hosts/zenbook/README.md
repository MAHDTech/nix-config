# ASUS Zenbook A14 — NixOS Issue Tracker

> Snapdragon X Elite (X1E80100 / UX3407RA) · Adreno X1-85 · aarch64
> Kernel: linux-next `next-20260611` · Mesa 26.1.1 (freedreno) · NixOS 26.05

---

## Active Status & Task Tracker

- 🟡 **Issue 3**: [GPU frequency hard-capped at 390 MHz](#issue-3-gpu-frequency-hard-capped-at-390-mhz) (P1) — _Regression; GPU uncapped in default boot, but `power-safe` cap fallback is set up._
- 🟡 **Issue 7**: [DSP subsystem (qcom_q6v5_pas) enablement](#issue-7-dsp-subsystem-qcom_q6v5_pas-enablement) (P3) — _Late-load crash analyzed; Stage 1 firmware fix deployed in Gen 32._
- 🟡 **Issue 16**: [Thunderbolt 5 dock drops to USB 2.0 full-speed](#issue-16-thunderbolt-5-dock-drops-to-usb-2-0-full-speed) (P1) — _Blocked on upstream kernel patches for non-PCIe host routers._
- 🟡 **Issue 21**: [fw_devlink optimization](#issue-21-fw_devlink-optimization) (P2)
  — _TODO: replace `fw_devlink=permissive` with `fw_devlink.sync_state=timeout` once stability confirmed._
- 🔴 **Issue 22**: [Instant PMIC Hard Reset on Audio Playback](#issue-22-instant-pmic-hard-reset-on-audio-playback) (P0)
  — _New regression; starting audio stream triggers immediate hardware-level reboot._

> [!NOTE]
> All **fully resolved issues** (Issues 1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14,
> 15, 17, 18, and 20) have been archived in [resolved_issues.md](file:///boot/nixos/nix-config/nixos/hosts/zenbook/resolved_issues.md)
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

### Issue 7: DSP subsystem (qcom_q6v5_pas) enablement

- [/] **Status**: Blocked
  - **Workaround Active**: ADSP is blacklisted globally in the `no-adsp` and `power-safe` specialisations to force the TB5 dock into stable USB 2.0 fallback, avoiding Alt Mode lockups.
  - This disables native audio and battery telemetry as a necessary tradeoff for stable network connectivity.
- **Severity**: P3 — Future improvement.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix`
    (ADSP/CDSP firmware paths and modprobe ordering)
  - `nixos/hosts/zenbook/hardware/pd-mapper/` (pd-mapper daemon: switchable between userspace service and in-kernel module)

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

### Issue 21: fw_devlink optimization

- [ ] **Status**: TODO — waiting for `fw_devlink=permissive` stability confirmation
- **Severity**: P2 — Performance/correctness improvement
- **Symptom**: `fw_devlink=permissive` disables all strict device-link probe ordering
  system-wide, which may mask driver ordering bugs.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (kernelParams)

* **Planned Fix**:
  1. Replace `fw_devlink=permissive` with `fw_devlink.sync_state=timeout` — keeps
     probe ordering but gives up on stuck consumers after timeout
  2. Add `deferred_probe_timeout=60` — extends timeout for slow-probing remoteproc
  3. If stable, try returning to `fw_devlink=on` (kernel default)
  4. Long-term: upstream DT fixes from alexVinarskis to complete supplier-consumer
     bindings, eliminating the need for any workaround

---

### Issue 22: Instant PMIC Hard Reset on Audio Playback

- [ ] **Status**: Open
- **Severity**: P0 — Critical regression; playing audio instantly crashes/reboots the system.
- **Symptom**: Playing a video on YouTube or initiating any audio output via PipeWire/ALSA immediately
  triggers a hardware power-cut and reboot (PMIC hard reset).
- **Crash Signature**: The netconsole logs capture the initialization attempt followed by an abrupt power cut:
  ```
  [  785.354100]  MultiMedia1 Playback: ASoC: no backend DAIs enabled... UCM profile
  [  804.883441] soundwire sdw-master-1-0: trf on Slave 0 failed:-5 read addr 3452 count 1
  ```
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (un-blacklisted audio modules list)
  - `nixos/hosts/zenbook/hardware/firmware/default.nix` (audio topology / firmware files)

* **Root Cause & Fix Strategy**:
  - **Power Draw/Regulator Drop**: The WSA884x speaker amplifiers are class-D amplifiers that can draw up to 4W
    of power each. When a playback stream is opened (e.g., PCM 1 for speakers), the ASoC driver releases the
    reset line (GPIO 12) and initializes the amplifiers. This sudden current draw on the audio regulator
    rails (like `vreg_l15b_1p8` or `vreg_l12b_1p2`) may cause a voltage drop that triggers the PMIC's
    overcurrent/under-voltage protection (UVP/OCP), resulting in an instantaneous hardware shutdown.
  - **ADSP Watchdog Crash**: Alternatively, the SoundWire bus warnings (`trf on Slave 0 failed:-5`) indicate
    the amplifiers are failing to communicate. When the ADSP tries to stream to unattached amplifiers,
    it may enter a lockup state that triggers a watchdog reset.
  - **Workaround**: Re-blacklist the audio modules (`snd_soc_x1e80100`, `snd_soc_wsa884x`, `snd_soc_wcd938x`,
    `snd_soc_wcd938x_sdw`, `snd_soc_wcd_common`) to prevent PipeWire/ALSA from trying to open the sound card.
