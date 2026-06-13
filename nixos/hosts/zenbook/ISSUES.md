# ASUS Zenbook A14 — NixOS Issue Tracker

> Snapdragon X Elite (X1E80100 / UX3407RA) · Adreno X1-85 · aarch64
> Kernel: linux-next `next-20260611` · Mesa 26.1.1 (freedreno) · NixOS 26.05

---

## Active Status & Task Tracker

- 🟡 **Issue 16**: [Thunderbolt 5 dock drops to USB 2.0 full-speed](#issue-16-thunderbolt-5-dock-drops-to-usb-20-full-speed) (P1) — _Blocked on upstream kernel patches for non-PCIe host routers._
- 🟡 **Issue 21**: [fw_devlink optimization](#issue-21-fw_devlink-optimization) (P2)
  — _TODO: replace `fw_devlink=permissive` with `fw_devlink.sync_state=timeout` once stability confirmed._
- 🟡 **Issue 22**: [Audio playback causes PMIC hard reset](#issue-22-audio-playback-causes-pmic-hard-reset) (P2)
  — _Backlogged; all audio kernel modules blacklisted, using Bluetooth audio. Awaiting upstream fixes._
- 🟡 **Issue 23**: [CPU stress testing (stress-ng) triggers PMIC overcurrent hard reset](#issue-23-cpu-stress-testing-stress-ng-triggers-pmic-overcurrent-hard-reset) (P1)
  — _Active; stress-ng-cpu triggers hard resets in < 1 minute even when downclocked to 1.92 GHz. Investigating root causes (missing LMH DT nodes, SoundWire storm, GPU lock)._

> [!NOTE]
> All **fully resolved issues** (Issues 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
> 15, 17, 18, and 20) have been archived in [ISSUES_FIXED.md](ISSUES_FIXED.md)
> to keep this main issue tracker focused and actionable.

---

## Open & In-Progress Issues

### Issue 16: Thunderbolt 5 dock drops to USB 2.0 full-speed

- [/] **Status**: Blocked — upstream `qcom,usb4-hr` platform driver does not exist yet.
- **Severity**: P1 — Dock non-functional (12 Mbps billboard fallback).
- **Dock**: Razer Thunderbolt 5 Dock (`1532:0f53`)
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix`
    (Type-C/Alt Mode modules, `CONFIG_USB4=m` in kernel)
  - `nixos/hosts/zenbook/kernel.nix` (`CONFIG_UCSI_PMIC_GLINK`,
    `CONFIG_TYPEC_DP_ALTMODE`, `CONFIG_USB4`)

* **Current State** (diagnosed 2026-06-12):

  | Component                     | State                      | Speed                             |
  | ----------------------------- | -------------------------- | --------------------------------- |
  | Razer TB5 Dock                | **Billboard device**       | **12 Mbps** (Full Speed)          |
  | Fresco Logic Hub (internal)   | USB 2.0 Hub                | 480 Mbps                          |
  | Chrontel CH7213 DP bridges ×2 | Billboard                  | 12 Mbps                           |
  | USB Bus 6 (SuperSpeed)        | **EMPTY** — SS link failed | `usb6-port1: attempt power cycle` |

  **PD negotiation**: ✅ PD 3.1 working (dock powers laptop).
  **Alt modes**: ✅ Both TBT (`0x8087`) and DP (`0xff01`) are **active** on host side.
  **USB4 Host Router**: ❌ Does not exist — no driver, no DT node, no platform device.

* **Root Cause**:
  The `thunderbolt` module (`CONFIG_USB4=m`) exists but only supports **PCIe-attached** NHI
  host routers (x86 Intel/AMD). The X1E80100's USB4 Host Router is a **platform/memory-mapped**
  device with no PCIe BDF. The module loads but finds no matching device. Without a USB4
  tunnel, the dock presents as a 12 Mbps billboard with only management endpoints.

  The `pmic_glink` device link failures with the PS8833 retimers (`2-0008`, `5-0008`) also
  indicate broken retimer integration, which would need fixing even with a USB4 HR driver.

* **Upstream Patch Status**:

  <!-- cspell:ignore Dybcio Kurapati -->

  | Patch                              | Author           | Status                       | Target  |
  | ---------------------------------- | ---------------- | ---------------------------- | ------- |
  | Non-PCIe NHI prepwork (v5)         | Konrad Dybcio    | ✅ In `thunderbolt.git/next` | ~7.2    |
  | DT bindings: `qcom,usb4-hr`        | Konrad Dybcio    | 🔶 RFC (Sep 2025)            | —       |
  | DISP_CC USB4 resets                | Konrad Dybcio    | 🔶 Submitted (Nov 2025)      | —       |
  | QMP combo PHY USB4 mode            | Multiple         | 🔶 WIP                       | —       |
  | DWC3 multiport + eUSB2 wakeup      | Krishna Kurapati | ✅ Partially merged          | Various |
  | **`qcom,usb4-hr` platform driver** | —                | ❌ **Not yet submitted**     | —       |

  The **critical blocker** is the `qcom,usb4-hr` platform driver — it does not exist upstream.
  The NHI prepwork only creates the framework for non-PCIe hosts.

* **Timeline Estimate**:

  | Milestone                           | Estimate                       | Confidence |
  | ----------------------------------- | ------------------------------ | ---------- |
  | NHI non-PCIe prepwork mainline      | Kernel 7.2 (~Aug 2026)         | ✅ High    |
  | `qcom,usb4-hr` DT binding finalized | Kernel 7.3–7.4 (~Nov 2026)     | 🔶 Medium  |
  | Basic USB4 tunneling working        | Kernel 7.4–7.5 (~Feb–May 2027) | 🔶 Low-Med |
  | Full TB5 120 Gbps                   | 2027+                          | ❌ Low     |

* **Workaround**: Dedicated USB-C to Ethernet adapter (ASIX AX88179B, `usb-to-eth` at
  `10.10.1.90`) provides reliable 5 Gbps SuperSpeed network. Direct USB-C to DP adapters
  should also work since DP Alt Mode is active.

---

### Issue 21: fw_devlink optimization

- [ ] **Status**: Ready to test — research confirms Phase 2 is low-to-medium risk.
- **Severity**: P2 — Performance/correctness improvement.
- **Symptom**: `fw_devlink=permissive` disables all strict device-link probe ordering
  system-wide, which may mask driver ordering bugs.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (kernelParams)

* **Research Findings** (2026-06-12):

  **Dependency cycles**: 323 `Fixed dependency cycle` messages at boot (~100 unique).
  All are automatically resolved by the kernel. Breakdown:

  | Category                                 | Count | Impact                 |
  | ---------------------------------------- | ----- | ---------------------- |
  | CoreSight debug trace (tpda/tpdm/funnel) | ~270  | Harmless               |
  | USB/Type-C/PHY triangular cycles         | ~20   | Critical (auto-fixed)  |
  | Display (DP controllers/panel)           | ~15   | Critical (auto-fixed)  |
  | Clock controller ↔ PHY                   | 4     | Critical (auto-fixed)  |
  | Regulator (RPMH bob/smps)                | 4     | Important (auto-fixed) |
  | pmic_glink connector ↔ typec-mux         | 4     | Critical (auto-fixed)  |

  **Key finding**: Zero `Failed to create device link` errors. Zero permanently
  deferred probes. All subsystems operational. The kernel's cycle detection on
  7.1.0-rc7-next handles all X1E80100 cycles correctly.

  **Current kernel config**: `DRIVER_DEFERRED_PROBE_TIMEOUT=10`,
  `FW_DEVLINK_SYNC_STATE_TIMEOUT` is **not set** (strict/indefinite wait).

* **Risk Assessment**:

  | Risk                               | Likelihood | Impact |
  | ---------------------------------- | ---------- | ------ |
  | USB-C/Display fail to init         | Low        | High   |
  | Boot hangs on sync_state() wait    | Medium     | High   |
  | Increased boot time from deferrals | Medium     | Low    |
  | GPU init failure (GMU clock dep)   | Low        | High   |

  The main risk is `sync_state()` blocking indefinitely — mitigated by the timeout parameter.

* **Migration Path**:
  1. **Phase 1** (safe): `fw_devlink=permissive fw_devlink.sync_state=timeout deferred_probe_timeout=30`
     — validates timeout mechanism, same functional behavior as today
  2. **Phase 2** (recommended): `fw_devlink=on fw_devlink.sync_state=timeout deferred_probe_timeout=30`
     — enables strict probe ordering with safety net timeout
  3. **Phase 3** (future): Remove `clk_ignore_unused pd_ignore_unused` — only when
     upstream clock/PD drivers are fully mature (NOT safe on current kernels)
  4. **Phase 4** (future): Remove all workaround params — when upstream is fully ready

  `clk_ignore_unused` and `pd_ignore_unused` must **NOT** be removed yet — they are a
  separate concern from `fw_devlink` and still required for stability.

---

<!-- cspell:ignore gprsvc swrm -->

### Issue 22: Audio playback causes PMIC hard reset

- [ ] **Status**: Backlogged — all audio kernel modules blacklisted for stability.
      Bluetooth audio (via PipeWire) works as a workaround.
- **Severity**: P2 — No built-in speakers or headphone jack audio. Bluetooth audio works.
- **Symptom**: Playing any audio via PipeWire/ALSA immediately triggers a hardware-level
  PMIC overcurrent hard reset (instant power-cut and reboot).
- **Crash Signature** (from netconsole):
  ```
  [   23.522533] qcom-apm gprsvc:service:2:1: CMD timeout for [1001021] opcode
  [   32.925743] qcom-soundwire 6b10000.soundwire: SWR CMD error, fifo status 0x4e00c101
  [   38.066880] soundwire sdw-master-1-0: trf on Slave 0 failed:-5 read addr 3452 count 1
  ```
  SoundWire bus errors repeat every ~5 seconds from boot. Audio playback attempt causes
  the PMIC to overcurrent-shutdown.
- **Codebase References**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (audio module blacklist,
    `extraModprobeConfig` with `i_accept_the_danger` and softdeps)
  - `nixos/hosts/zenbook/hardware/firmware/` (audio topology / firmware files)

* **Root Cause Analysis**:
  - **WSA884x SoundWire failure**: The WSA884x speaker amplifier codec fails to
    communicate on SoundWire bus `6b10000.soundwire` (Slave 0, register 3452).
    The SoundWire controller enters a continuous error loop from boot, with FIFO
    flush + read underflow errors every ~5 seconds. This indicates the speaker amp
    hardware is not responding to SoundWire initialization commands.
  - **`i_accept_the_danger` parameter ignored**: On `next-20260611`, the kernel logs
    `snd_soc_x1e80100: unknown parameter 'i_accept_the_danger' ignored`. The safety
    bypass parameter may have been changed to a kernel command-line parameter
    (`snd-soc-x1e80100.i_accept_the_danger=1`) instead of a module parameter in recent
    kernels. Without this bypass, the driver may not properly gate the dangerous
    speaker amplifier path.
  - **PMIC overcurrent on playback**: When ALSA opens a PCM stream to the speakers,
    the ASoC driver releases the WSA884x reset line and initializes the class-D
    amplifiers (~4W each). The sudden current draw on audio regulator rails
    (e.g. `vreg_l15b_1p8`, `vreg_l12b_1p2`) triggers the PMIC's overcurrent/under-voltage
    protection, causing an instantaneous hardware shutdown.
  - **Upstream reference**: thomas.kuang reported the same issue on Lenovo ThinkBook 16 G7
    (X1E80100) on 2026-06-08 via lore.kernel.org (`[BUG] No soundcards detected`).
    Ubuntu 7.0.0-22-generic also requires the `i_accept_the_danger` parameter for
    sound card registration.

* **Current Workaround**:
  All five audio kernel modules are blacklisted in `hardware-configuration.nix`:

  ```
  snd_soc_x1e80100      — machine driver
  snd_soc_wsa884x       — speaker amplifier codec (WSA884x)
  snd_soc_wcd938x       — headphone codec (WCD938x)
  snd_soc_wcd938x_sdw   — WCD938x SoundWire transport
  snd_soc_wcd_common    — WCD common ops
  ```

  Audio is provided via Bluetooth headphones through PipeWire.

* **Future Investigation** (for when upstream fixes land):
  1. **Try headphone-only**: Un-blacklist only `snd_soc_wcd938x` (headphones) while
     keeping `snd_soc_wsa884x` (speakers) blacklisted. The WCD938x headphone codec
     may work independently without triggering the WSA884x SoundWire crash path.
  2. **Verify `i_accept_the_danger`**: Check if the parameter moved to kernel cmdline
     format (`snd-soc-x1e80100.i_accept_the_danger=1`) or was removed entirely.
     Search `sound/soc/qcom/x1e80100.c` in the kernel source.
  3. **SoundWire bus debugging**: The `trf on Slave 0 failed:-5 read addr 3452`
     error suggests a register read failure at SoundWire address 3452 on the WSA884x.
     This could be a power sequencing issue, missing DT bindings, or firmware
     incompatibility.
  4. **Monitor upstream**: Track patches to `sound/soc/qcom/x1e80100.c` and
     `drivers/soundwire/qcom.c` for X1E80100 speaker amp fixes.

---

### Issue 23: CPU stress testing (stress-ng) triggers PMIC overcurrent hard reset

- [/] **Status**: Active — **likely root cause identified**: insufficient USB-C Power Delivery
  through TB5 dock (linked to Issue 16). CPU cooling DT overlay deployed.
- **Severity**: P1 — System hard-resets under heavy CPU load.
- **Symptom**: Instantaneous hard reset (power-cut and reboot) within < 2 minutes when
  running `sudo stress-ng --cpu 12 --timeout 120s` at any frequency.
- **Codebase References**:
  - `nixos/hosts/zenbook/kernel.nix` (`CONFIG_QCOM_LMH`, `CONFIG_ARM_SCMI_POWERCAP`)
  - `nixos/hosts/zenbook/power.nix` (CPU frequency configuration and telemetry logger)
  - `nixos/hosts/zenbook/files/cpu-cooling-overlay.dts` (NEW — passive trip cooling-maps)
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (DT overlay registration,
    SoundWire blacklist, `force-acpi` specialisation)

* **Critical Discovery — USB-C PD Root Cause (2026-06-13)**:

  All stress test crashes occurred while powered through the **Razer TB5 dock** (Issue 16),
  which drops to USB 2.0 billboard mode under Linux. The UCSI power supply reports:

  ```
  VOLTAGE_MAX=0  CURRENT_MAX=0  VOLTAGE_NOW=0  CURRENT_NOW=0
  USB_TYPE=C [PD] PD_PPS
  AC online=0  USB online=1
  ```

  **Linux cannot read the PD contract parameters** negotiated through the dock. The dock
  may have been delivering only 15W (USB default) instead of 65W+, forcing the PMIC to
  draw from battery for all sustained loads.

  > [!WARNING]
  > **UPDATE**: Testing on the **direct AC charger** (bypassing dock) also crashes — but
  > at higher frequencies. The frequency ladder test passed 1.19 GHz and 1.44 GHz (60s
  > each, 12 cores) but crashed during the **1.67 GHz** step. On the dock, even 998 MHz
  > crashed when run back-to-back. The dock worsens the power budget but the **underlying
  > PMIC OCP is genuinely tight** — the safe sustained all-core ceiling is ~1.44 GHz.
  > Windows survives because PEP actively manages the power budget, not just PD delivery.

* **Stress Test Results Matrix (2026-06-13)**:

  **Installed OS tests** (AC via TB5 dock unless noted):

  | Frequency | Cores | Duration | Cooldown | Result   | Notes                             |
  | --------- | ----- | -------- | -------- | -------- | --------------------------------- |
  | 3.4 GHz   | 12    | ~90s     | Cold     | ❌ Crash | 60°C CPU — well below 75°C trip   |
  | 2.2 GHz   | 12    | ~90s     | None     | ❌ Crash | 41°C CPU — freq cap had no effect |
  | 1.44 GHz  | 12    | ~90s     | None     | ❌ Crash | 34°C CPU — not thermal at all     |
  | 998 MHz   | 12    | Instant  | None     | ❌ Crash | Back-to-back accumulated stress   |
  | 998 MHz   | 12    | 30s      | 60s      | ✅ Pass  | 31°C CPU, PMIC 37°C               |
  | 1.19 GHz  | 6     | 30s      | Fresh    | ✅ Pass  | First clean pass                  |

  **Installed OS — isolation tests** (direct AC charger, installer-mimic specialisation):

  | Test                       | Freq at crash | Time | Result   | Notes                                     |
  | -------------------------- | ------------- | ---- | -------- | ----------------------------------------- |
  | installer-mimic            | ~2.97 GHz     | ~30s | ❌ Crash | Cooling throttled from 3.4 but OCP'd      |
  | WiFi unbound from PCIe     | ~2.7 GHz      | ~30s | ❌ Crash | WiFi NOT the cause                        |
  | RO root (attempted)        | ~2.7 GHz      | ~30s | ❌ Crash | Couldn't fully remount RO                 |
  | Services killed at runtime | ~1.92 GHz     | ~30s | ❌ Crash | Stopped logind/polkit/dbus/resolved       |
  | Matched installer params   | ~2.7 GHz      | ~30s | ❌ Crash | Removed nohibernate/quiet/splash/apparmor |
  | sha256sum ×12 (NOT stress) | 3.4 GHz       | ~25s | ❌ Crash | 51°C — NOT stress-ng specific!            |

  **Live installer tests** (direct AC charger, USB boot, same kernel + DT + overlays):

  | Test                     | Freq        | Duration  | Result  | Notes                                     |
  | ------------------------ | ----------- | --------- | ------- | ----------------------------------------- |
  | sha256sum ×12 cores      | 3.4 GHz     | **5 min** | ✅ Pass | 54°C steady, throttled to 2.7 last min    |
  | stress-ng --cpu 12 (all) | 2.1–3.2 GHz | **5 min** | ✅ Pass | 580K bogo ops, 12/12 passed, 0 failed     |
  | stress-ng + NVMe dd 10GB | 2.1–3.2 GHz | **5 min** | ✅ Pass | 613K bogo ops + 427 MB/s NVMe write, 58°C |

  > [!IMPORTANT]
  > **All three installer tests pass — including simultaneous CPU + NVMe I/O.**
  > The installed OS crashes in ~30 seconds with the same frequencies and temperatures.
  > Same kernel, same device tree (with overlays), same cooling maps, same charger.
  >
  > **Ruled out as root cause:**
  >
  > - ❌ NVMe/PCIe power draw (installer survives 10GB write + stress-ng)
  > - ❌ WiFi/PCIe power draw (unbound WiFi didn't help installed OS)
  > - ❌ Thermal (same temps on both, crashes at 52-54°C)
  > - ❌ stress-ng specific (sha256sum also works on installer)
  > - ❌ Device tree (identical model, overlays, trip points, thermal zones)
  > - ❌ Kernel (same binary: 7.1.0-rc7-next-20260611)
  > - ❌ Power delivery (same direct AC charger)
  > - ❌ Cooling maps (both have 55°C passive trip, same throttling behaviour)
  >
  > **Root cause is in the installed OS boot/service configuration** — something a
  > systemd service or NixOS module configures changes PMIC regulator state or OCP
  > thresholds. Modules are identical (72 on both). Next: binary search services.

* **Architecture — Why Windows Works (Research Findings)**:

  | Layer          | Windows                                     | Linux                                       |
  | -------------- | ------------------------------------------- | ------------------------------------------- |
  | Power Budget   | PEP (Power Engine Plugin) — Qualcomm binary | ❌ Nothing                                  |
  | CPU Throttling | PEP → firmware + ACPI `_PPC/_PCT`           | ❌ No cooling-maps (our overlay adds these) |
  | LMH Hardware   | TrustZone-managed (cooperates with PEP)     | TrustZone only (no PEP cooperation)         |
  | DDR Scaling    | PEP memory latency management               | ❌ No memlat driver                         |
  | USB-C PD       | Full negotiation via PEP + dock driver      | ❌ Broken (zero values in UCSI)             |

  **No x1e80100 board DTS has CPU cooling-maps** — the gap is universal across ALL boards
  (Dell, HP, Lenovo, Microsoft, ASUS, TUXEDO). Our overlay is ahead of upstream.

  LMH is intentionally managed by TrustZone firmware on X1E80100 (no kernel interaction).
  SCMI Powercap (`protocol@19`) is absent from the firmware DT — cannot be fixed via overlay.

* **Deployed Mitigations (2026-06-13)**:
  1. **CPU cooling-maps DT overlay** (`cpu-cooling-overlay.dts`):
     - Adds `passive` trip at 75°C + `cooling-maps` to `cpuss{0,1,2}-top-thermal`
     - Wires `cpufreq-cpu{0,4,8}` cooling devices via `step_wise` governor
     - 100ms polling delay for responsive throttling
     - Verified active: trip points, cooling devices, and bindings all confirmed in sysfs

  2. **SoundWire IRQ storm eliminated**:
     - Blacklisted `soundwire_qcom` and `snd_soc_lpass_*_macro` modules
     - SoundWire interrupts dropped from ~6,769 to **zero**
     - Reduces baseline PMIC load from spurious bus activity

  3. **GPU 390 MHz cap** (existing): Udev rule limits GPU frequency.

  4. **`force-acpi` boot specialisation**: systemd-boot entry with `acpi=force` for
     ACPI table extraction. Note: causes instant hard reset — Qualcomm ACPI tables
     are Windows-only stubs. ACPI tables must be extracted via `/dev/mem` instead
     (requires disabling `CONFIG_STRICT_DEVMEM`).

  5. **`disable-gpu` boot specialisation** (NEW): systemd-boot entry with `module_blacklist=msm` and
     `regulator_ignore_unused` to completely disable the GPU driver and boot into a text console.
     Isolates GPU rail power draw from CPU stress tests.

  6. **`text-mode` boot specialisation** (NEW): systemd-boot entry booting directly into `multi-user.target`
     console but leaving `msm` active. Isolates idle GPU power draw from active desktop rendering draw.

* **SMBIOS Power Data**:

  ```
  Processor: Snapdragon X Elite - X1E78100 (12 cores, no HT)
  Voltage: 1.1V
  Max Speed: 3400 MHz
  Battery: 70Wh (Li-ion, 13 cycles, manufactured 2025-04-20)
  Charger: USB-C PD 3.1 with PPS
  ```

* **Next Steps**:
  1. **Deploy and Test Diagnostic Specialisations**:
     - Boot into `disable-gpu` specialization and run all-core `stress-ng` (at 3.42 GHz) to verify if the main system achieves the same stability as the live installer.
     - Boot into `text-mode` specialization and run the same test to verify if the idle GPU power draw alone changes the PMIC OCP budget.
  2. **Validate with direct AC charger**: Run `stress-ng --cpu 12 --timeout 300s` at
     full 3.4 GHz using the direct AC charger (not via TB5 dock). If this passes,
     Issue 23 is resolved by Issue 16.
  3. **Investigate PD negotiation**: Check if direct AC charger shows non-zero
     `VOLTAGE_MAX` / `CURRENT_MAX` in UCSI sysfs.
  4. **ACPI table extraction**: Disable `CONFIG_STRICT_DEVMEM` temporarily, read
     RSDP at `0xd47d3018` via `/dev/mem`, decompile DSDT/SSDT to find PEP power limits.
  5. **Monitor upstream**: `#cooling-cells` patch for Oryon CPUs is in review (Feb 2026).
     Once merged, CPU cooling-maps should follow in the base DTSI.
  6. **Consider `dynamic-power-coefficient`**: Add to CPU nodes in a second overlay
     to enable `power_allocator` governor for intelligent power allocation.
