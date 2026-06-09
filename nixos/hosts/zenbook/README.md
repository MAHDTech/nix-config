# ASUS Zenbook A14 — NixOS Issue Tracker

> Snapdragon X Elite (X1E80100 / UX3407RA) · Adreno X1-85 · aarch64
> Kernel: linux-next `next-20260605` · Mesa 26.1.1 (freedreno) · NixOS 26.05

Work through issues **one at a time** — build, test, verify, then check off before moving on.

> [!IMPORTANT]
> **Current generation**: Gen 5 (next-20260605 upgrade, 2026-06-09).
> Partition layout: ESP (1G) / pstore (16M) / btrfs (953G).
> Previous generations wiped — this is a clean install.

---

## Active Tasks & Learnings (Ubuntu -> NixOS Transition)

We are running testing on Ubuntu first to identify working configurations, then porting those settings to NixOS.

### Ubuntu Win/Loss Log

- **Win: GPU Hardware Acceleration**: Fully functional!
  - _Learning_: Mesa Turnip (Vulkan) and Gallium (OpenGL) require `gen70500_sqe.fw` and
    `gen70500_gmu.bin` decompressed. The kernel had trouble loading the `.zst` compressed
    versions during early display init. Decompressing them into `/lib/firmware/qcom/`
    resolved the `DEVICE_LOST` and GMU timeouts, bringing the GPU to `active` state at
    300MHz+.
- **Win: Audio & Battery**: Fully functional!
  - _Learning_: The ADSP (`remoteproc0`) firmware (`qcadsp8380.mbn`) fails to load during
    early boot (at ~1.1s) because the root filesystem isn't mounted yet. Manually
    starting the remoteproc device post-boot
    (`echo start > /sys/class/remoteproc/remoteproc0/state`) allows it to successfully
    pull the firmware from the rootfs. This instantly starts the DSP, registers the
    glink channel, brings the battery capacity online, and enables the SoundWire audio
    speakers!
  - _Note_: Battery status checked successfully via `upower -i /org/freedesktop/UPower/devices/battery_qcom_battmgr_bat` (reporting 100% capacity/charge, fully functional).
- **Loss: Dock Alt Mode Lockup/Disconnect**:
  - _Learning_: Starting ADSP triggers the `pmic_glink_altmode` negotiator. If
    `thunderbolt` is blacklisted or the retimer driver (`ps883x`) is missing during
    negotiation, the dock's USB lanes get misconfigured: it either crash-loops the PCIe
    bus (if plugged in during boot) or disconnects and drops back to slow USB 2.0 mode
    (if plugged in post-boot).
  - _Workaround_: We established a WiFi backdoor (`10.10.2.112`) and separate USB-to-Ethernet adapter (`10.10.1.90`) to maintain SSH access while testing the dock's failure states.

### Active Tasks Checklist

- [x] Re-establish stable SSH/network connection to Zenbook on Ubuntu (achieved via WiFi backdoor and separate USB-Ethernet adapter).
- [ ] Clean up modprobe config on Ubuntu (done: removed thunderbolt blacklist to stop boot loop).
- [ ] Write post-boot ADSP/CDSP auto-start script/systemd unit on Ubuntu to automate testing.
- [ ] Port learnings to NixOS config:
  - [ ] Ensure `gen70500_sqe.fw` and `gen70500_gmu.bin` are correctly placed and uncompressed in the NixOS firmware store.
  - [ ] Implement a systemd service in NixOS to trigger `echo start` on `remoteproc0`
        and `remoteproc1` after the local filesystems (and thus `/nix/store` firmware)
        are mounted. This will natively enable battery and audio on boot without bloating
        the initrd.
  - [ ] Test the Thunderbolt Alt Mode stack on NixOS with ADSP running post-boot. Since all drivers (including `ps883x` retimer) will be fully loaded, negotiation should succeed or fail gracefully.

---

## Issues

### Issue 1: Vulkan rendering broken (vkcube blank, vkmark DEVICE_LOST)

- [x] **Status**: Resolved (DRM_SYNCOBJ fix verified with vkcube running stable under Wayland)
- **Severity**: P0 — Vulkan apps don't render / crash
- **Symptom**:
  - `vkcube` renders one frame (static cube) then hangs — "application not responding"
  - `vkmark` crashes on first test with `vk::Device::waitIdle: ErrorDeviceLost` + core dump
  - `vulkaninfo --summary` works and shows Adreno X1-85 via Turnip (Vulkan 1.4.348)
  - Lavapipe (software Vulkan) renders spinning cube perfectly — confirms Vulkan WSI/swapchain is fine
- **Root Cause**: **`CONFIG_DRM_SYNCOBJ` is missing from the kernel config.**
  Turnip (freedreno Vulkan) requires DRM syncobjs for GPU command synchronization
  between frames. Without it, the first frame renders but subsequent frames hang
  because the driver can't signal/wait on submission fences.
  OpenGL (freedreno Gallium) uses a different synchronization path and works fine without it.
- **Files changed**:
  - `nixos/hosts/zenbook/kernel.nix` — Added `DRM_SYNCOBJ` and `DRM_SYNCOBJ_TIMELINE_EXPORT` enables
  - `nixos/system/config/video/qcom/default.nix` — Moved `vulkan-tools` to `environment.systemPackages`
- **Files**:
  - `nixos/system/config/video/qcom/default.nix` — Move `vulkan-tools` to `environment.systemPackages` so `vulkaninfo`/`vkcube` are on PATH without nix-shell
  - `scripts/test-hardware.sh` — Consider adding Wayland WSI tests (run vkcube under Wayland directly)
- **Investigation**:

  ```bash
  # Test vkcube under Wayland WSI instead of XCB:
  vkcube --present_mode fifo  # With VSync

  # Test with explicit GPU selection:
  MESA_VK_DEVICE_SELECT=5143:43050c01 vkcube

  # Check CMA usage:
  cat /proc/meminfo | grep Cma

  # Check for GPU faults in dmesg after vkmark crash:
  sudo dmesg | tail -20
  ```

- **Notes**:
  - OpenGL is fully working — glxgears hits 3000-3500 FPS at 390 MHz even with `vblank_mode=0`
  - `libvulkan_freedreno.so` and `freedreno_icd.aarch64.json` are present in `/run/opengl-driver/`
  - This may be a Turnip driver maturity issue on Adreno X1-85 (gen7) — freedreno Vulkan for this GPU generation is still relatively new in Mesa
  - Increasing the GPU freq cap (Issue 3) is unlikely to fix this since DEVICE_LOST happens even at 390 MHz

---

### Issue 2: Iris video codec firmware path mismatch

- [x] **Status**: Resolved (GStreamer hardware encode pipeline verified successfully, firmware `qcvss8380.mbn.zst` correctly loaded and decompressed from `/run/current-system/firmware`)
- **Severity**: P1 — No hardware video decode/encode
- **Symptom**: Repeated dmesg errors:
  ```
  qcom-iris aa00000.video-codec: Direct firmware load for
    qcom/x1e80100/ASUSTeK/zenbook-a14/qcvss8380.mbn failed with error -2
  qcom-iris aa00000.video-codec: firmware download failed
  qcom-iris aa00000.video-codec: core init failed
  ```
- **Root Cause**: `firmware-windows.nix` extracts `qcvss8380.mbn` from the Windows
  driver package, but the file isn't found on the live system at the expected path.
  Either the extraction output path doesn't match what the kernel expects
  (`qcom/x1e80100/ASUSTeK/zenbook-a14/qcvss8380.mbn`), or the firmware store
  composition isn't picking it up correctly.
- **Files**:
  - `nixos/hosts/zenbook/hardware/firmware-windows.nix` — extraction logic
  - `nixos/hosts/zenbook/files/patches/0018-WIP-arm64-dts-qcom-x1-asus-zenbook-a14-enable-Iris.patch` — DTS that defines the firmware path
- **Fix**: Verify the output directory structure in `firmware-windows.nix` places
  the file at `lib/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14/qcvss8380.mbn`.
  If the extraction puts it elsewhere, fix the path mapping.
- **Test**:
  ```bash
  # After rebuild:
  find /run/current-system/firmware -name "qcvss8380.mbn"
  sudo dmesg | grep -i "iris\|qcvss"  # Should show successful load
  ```
- **Notes**: Patch 0018 is marked WIP — "Does not start on Purwa/x1-26-100
  variant". If firmware loads but codec still fails, the fallback is to remove
  the patch and disable Iris until upstream stabilises.

---

### Issue 3: GPU frequency hard-capped at 390 MHz

- [ ] **Status**: Regression in Gen 2. Removing the cap allowed the GPU to reach
      `1.25 GHz` but caused an instant PMIC overcurrent hard reboot under GPU load
      (`vkmark`). We must restore a conservative cap (e.g. 550 MHz or 687 MHz).
- **Severity**: P1 — GPU at ~31% max performance
- **Symptom**: `cat /sys/class/devfreq/3d00000.gpu/max_freq` → `390000000`
- **Root Cause**:
  - `systemd.services.gpu-frequency-cap` in `hardware-configuration.nix` writes `390000000` to prevent overcurrent crashes caused by GPU dummy regulators
    (`vdd` and `vddcx` on `regulator-dummy` at 0mV/0mA). On x1e80100.
  - voltage is managed by RPMh Power Domains and the GMU.
  - Because `vddcx-supply` isn't mapped to a physical RPMh regulator node in the device tree, `regulator_set_voltage()` does nothing. When frequency scales up, voltage remains low.
  - This causes massive current spikes that trip the PMIC's hardware Overcurrent Protection (OCP) and reboot the system.
- **Fix Strategy**:
  - Upstream resolution involves proper GMU / RPMh Power Domain mapping,
  - and the newly introduced **GPU ACD (Adaptive Clock Distribution)** patches.
  - These are specifically designed for the Adreno X1-85 to prevent current spikes.
  - Until ACD patches are ported/stabilised in our kernel, we must maintain a conservative frequency cap.
- **File**: `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (line ~152-161)
- **Fix**: Incrementally raise the cap and stress-test at each step. Test order:
  1. `550000000` (550 MHz — ~44% max)
  2. `687000000` (687 MHz — ~55% max)
  3. `800000000` (800 MHz — ~64% max)
  4. `925000000` (925 MHz — ~74% max) — probably the safe ceiling
- **Test** at each frequency:

  ```bash
  # Quick validation (with VSync, should not crash):
  glxgears  # Run for 30 seconds
  vblank_mode=3 nix run nixpkgs#glmark2  # Run full benchmark suite

  # Stress test (careful — this previously caused reboots):
  # Only after confirming stable at the target freq with VSync
  vblank_mode=0 nix run nixpkgs#glmark2  # Uncapped frame rate — watch for reboot

  # Check thermal:
  paste <(cat /sys/class/thermal/thermal_zone*/type) \
        <(cat /sys/class/thermal/thermal_zone*/temp) | grep gpuss
  ```

- **Notes**:
  - **OpenGL is stable at 390 MHz even with vsync off** — glxgears runs
    3000-3500 FPS (vblank_mode=0) without crashing. This suggests 390 MHz
    is a conservative cap for OpenGL; higher frequencies may be safe.
  - Keep `vblank_mode=3` and `MESA_VK_WSI_PRESENT_MODE=fifo` env vars as the default safety net
  - `regulator-dummy` reports 0mV/0mA for both `3d00000.gpu-vdd` and
    `3d00000.gpu-vddcx`. The actual silicon is powered by always-on PMIC rails
    but the kernel can't scale voltage. This is an upstream device-tree limitation.
  - Monitor `gpucc-x1e80100 3d90000.clock-controller: sync_state() pending due to 3d6a000.gmu` — this may resolve at higher kernel versions
  - Vulkan DEVICE_LOST (Issue 1) happens even at 390 MHz, so raising freq won't fix Vulkan — but may improve OpenGL perf significantly

---

### Issue 4: Firmware source consolidation / audit

- [x] **Status**: Resolved (Audit report completed. Verified 100% clean separation of files between local OEM-signed ADSP/CDSP sources, Qualcomm build-time zip extraction, and upstream linux-firmware)
- **Severity**: P2 — Risk of version conflicts
- **Symptom**: Three separate firmware sources provide overlapping GPU firmware files
- **Root Cause**: The firmware loading chain has three packages:
  1. `firmware.nix` — local blobs from `files/firmware/` (GPU KMD `qcdxkmsuc8380.mbn`, ADSP, CDSP)
  2. `firmware-windows.nix` — 17 files extracted from Qualcomm Windows GPU driver v31.0.148.0 (includes `qcdxkmsuc8380.mbn` duplicates, zap shaders, video codec FW)
  3. Inline `runCommand` — `gen70500_*` from `linux-firmware` (generic GPU SQE + GMU)
- **Files**:
  - `nixos/hosts/zenbook/hardware/firmware.nix`
  - `nixos/hosts/zenbook/hardware/firmware-windows.nix`
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (inline runCommand)
- **Fix**: Audit all three sources for duplicated files. Document which file comes from which source and which version wins in the firmware search path. Remove duplicates where possible.
- **Test**:
  ```bash
  # List all firmware files and their origins:
  find /run/current-system/firmware/qcom -type f | sort
  # Compare against dmesg for what's actually loaded:
  sudo dmesg | grep -i "loaded\|firmware" | grep qcom
  ```

---

### Issue 5: pstore/ramoops not configured for crash debugging

- [/] **Status**: Partially verified on Gen 6 (2026-06-06):
  - ✅ **ramoops**: `pstore: Registered ramoops as persistent store backend`, `using 0x200000@0xb7000000, ecc: 0` — NO ECC errors!
  - ✅ **netconsole**: systemd service `active (exited)`, configured with source IP `10.10.1.90 → 10.10.1.93:6666`, `network logging started`
  - ✅ **panic settings**: `panic_on_oops=1 panic=30 panic_print=0x7ff` confirmed in kernel params
  - ✅ **efi-runtime-test**: specialisation boot entry present in systemd-boot
  - ⚠️ **pstore-blk**: partition exists (`disk-main-pstore`, 16M) but kernel param had wrong label — **fixed** (was `/dev/disk/by-partlabel/pstore`, now `/dev/disk/by-partlabel/disk-main-pstore`)
  - ❌ **pstore dir**: empty (no crashes yet — expected)
- **Severity**: P0 — No crash dumps captured on any crash type
- **Symptom**: `/sys/fs/pstore/` is empty after every boot. `ramoops: uncorrectable error in header` ×10 on every boot.
- **Root Cause**: Three independent failures:
  1. **`memmap=` is x86-only** — ARM64 ignores it entirely (kernel says `Unknown kernel command line parameters: memmap=1M$0xbed00000`)
  2. **No ramoops node in DTB** — ARM64 requires `reserved-memory` with `no-map` in the Device Tree
  3. **`efi=noruntime` blocks EFI pstore** — disables `SetVariable()` needed by `efi_pstore`
- **Compounding factors**:
  - `panic_on_oops=0` — oops events never flush to pstore
  - `panic=0` — system hangs forever on panic instead of rebooting
  - `sysrq=16` — only sync allowed, no emergency crash dump trigger
  - PMIC hard resets (hardware power cut) — no kernel execution time to write pstore
- **Files changed**:
  - `nixos/hosts/zenbook/files/ramoops-overlay.dts` — DT overlay reserving 2MB at `0xb7000000` with `no-map`. ECC disabled (`ecc-size=0`) — headers never initialise cleanly on this platform.
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` —
    Removed broken `memmap=`/`ramoops.*` params; added DTB overlay,
    panic settings, sysctl, pstore-blk kernel param. Removed netconsole
    from boot-time modules (moved to systemd service). Added `efi-runtime-test`
    specialisation to test removing `efi=noruntime`.
  - `nixos/hosts/zenbook/netconsole.nix` — [NEW] Systemd service that loads
    netconsole after `network-online.target`, dynamically discovering source IP
    from `enu2c2`. Replaces unreliable boot-time module loading.
  - `nixos/hosts/zenbook/kernel.nix` — Added `CONFIG_NETCONSOLE`, `CONFIG_NETCONSOLE_DYNAMIC`, `CONFIG_PSTORE_BLK`
  - `nixos/hosts/zenbook/disko-config.nix` — Added 16MB `pstore` partition for pstore-blk
  - `nixos/hosts/jons/default.nix` — Added netconsole receiver service (ncat UDP 6666 → `/var/log/netconsole-zenbook.log`) and firewall rule
- **Crash capture layers** (defense in depth):
  | Layer | Captures panics? | Captures PMIC resets? | Status |
  |:---|:---:|:---:|:---|
  | DTB ramoops (2MB reserved) | ✅ | ❌ | ✅ **Verified Gen 6** — ecc: 0, no errors |
  | Panic escalation settings | ✅ (enables flush) | ❌ | ✅ **Verified Gen 6** — kernel params confirmed |
  | Netconsole → JONS:6666 | ✅ (live) | ⚠️ Pre-crash only | ✅ **Verified Gen 6** — systemd service active, logging started |
  | pstore-blk (NVMe partition) | ✅ | ⚠️ Maybe | ⚠️ Partition exists, label fix pending rebuild |
- **Test**:
  ```bash
  # 1. Verify ramoops DTB node
  cat /sys/firmware/devicetree/base/reserved-memory/ramoops@b7000000/compatible
  # 2. Verify pstore registered without errors
  dmesg | grep -i 'ramoops\|pstore'  # Should show 0x200000@0xb7000000, NO uncorrectable errors
  # 3. Test pmsg persistence
  echo "test_$(date)" > /dev/pmsg0 && reboot
  cat /sys/fs/pstore/pmsg-ramoops-0  # Should show test message
  # 4. Test netconsole (check JONS)
  ssh JONS cat /var/log/netconsole-zenbook.log
  # 5. Controlled panic test (CAREFUL)
  echo c > /proc/sysrq-trigger  # Will reboot in 30s
  cat /sys/fs/pstore/dmesg-ramoops-0  # Should show panic trace
  ```

---

### Issue 6: Defconfig regeneration and platform trimming

- [x] **Status**: Resolved (Disabled irrelevant SoC architectures like Exynos, Tegra, Mediatek, and Rockchip to significantly reduce kernel compile times).
- **Severity**: P3 — Housekeeping
- **Symptom**: Defconfig header says `7.1.0-rc5` but kernel source is `rc6`. Many non-Qualcomm platforms enabled (Exynos, Tegra, Mediatek, etc.) increasing kernel size.
- **Root Cause**: The trimming process disabled core `MAILBOX` and
  `ARM_SCMI_PROTOCOL` frameworks, which Qualcomm platforms require
  for PMIC/firmware clock and regulator communication during boot.
- **Fix**: Force-enable SCMI and Mailbox config flags in `kernel.nix` during configurePhase.
- **Test**:
  ```bash
  # Rebuild and boot — verify no regressions
  uname -a  # Same kernel version
  lsmod | wc -l  # Similar module count
  sudo dmesg | grep -i error | wc -l  # No new errors
  ```

---

### Issue 7: DSP subsystem (qcom_q6v5_pas) enablement

- [x] **Status**: Resolved (ADSP/CDSP are unblacklisted, audio speakers/microphones functional, and remoteproc is active)
- **Severity**: P3 — Future improvement
- **Symptom**: `qcom_q6v5_pas` is triple-blacklisted (kernel param + blacklistedKernelModules + modprobe install). ADSP/CDSP firmware and pd-mapper configs are bundled but unused.
- **Root Cause**: Previously caused NVMe/PCIe power domain/SMMU crashes.
- **Files**:
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (blacklist entries)
  - `nixos/hosts/zenbook/hardware/pd-mapper.nix` (daemon config with ConditionPath guards)
- **Fix**: When ready, test unblacklisting on a new NixOS generation (keep previous generation as rollback).
- **Test**:
  ```bash
  # After unblacklisting:
  lsmod | grep q6v5  # Should be loaded
  ls /sys/class/remoteproc/  # Should show ADSP/CDSP
  systemctl status pd-mapper  # Should be active
  # Test NVMe is still working:
  dd if=/dev/nvme0n1 of=/dev/null bs=1M count=100  # Should complete without crash
  ```
- **Notes**: Only attempt after all higher-priority issues are resolved and system is stable. Always keep a rollback generation.

---

### Issue 8: PCIe ASPM re-enablement for battery life

- [x] **Status**: Resolved (`pcie_aspm=off` removed, allowing hardware-managed link states and extending battery life)
- **Severity**: P3 — Battery optimization
- **Symptom**: `pcie_aspm=off` in kernel params disables PCIe Active State Power Management system-wide. PCIe dummy regulators retry ~20x during boot for controller `1c08000`.
- **File**: `nixos/hosts/zenbook/hardware/hardware-configuration.nix` (kernelParams)
- **Fix**: Test removing `pcie_aspm=off` or using `pcie_aspm=default` to let the BIOS/firmware policy apply. Monitor for NVMe/WiFi link stability.
- **Test**:
  ```bash
  # After removing pcie_aspm=off:
  cat /sys/module/pcie_aspm/parameters/policy  # Check active policy
  # Stress test NVMe:
  fio --name=test --rw=randrw --bs=4k --size=1G --numjobs=4 --time_based --runtime=60
  # Test WiFi:
  ping -c 100 8.8.8.8  # Check for packet loss
  # Monitor power:
  cat /sys/class/power_supply/qcom-battmgr-bat/current_now
  ```

### Issue 9: Razer Thunderbolt 5 Dock Ethernet regression (USB disconnect / Alt Mode negotiation failure)

- [/] **Status**: Upstream fixes (`ps883x` retimers and `UCSI_USB4_IMPLIES_USB`) integrated in `next-20260605`. Testing if Alt Mode lockups are resolved.
- **Severity**: P0 — High-speed dock peripherals and Ethernet not detected
- **Symptoms**:
  - The Razer TB5 Dock USB tree initializes during early boot but is disconnected as soon as the ADSP remoteproc boots and `pmic-glink` initiates Type-C port manager negotiation.
  - High-speed USB hub and Realtek Gigabit NIC fail to reconnect.
- **Root Cause**:
  - The Type-C port manager attempts to negotiate alternate modes, causing a connection reset.
  - However, because the kernel lacks DisplayPort and Thunderbolt Alt Mode drivers (`CONFIG_TYPEC_DP_ALTMODE` and `CONFIG_TYPEC_TBT_ALTMODE`),
  - and because the Parade PS883X retimer driver is loaded too late (stage 2 instead of initrd stage 1,
  - causing a `pmic-glink` device link failure), the negotiation fails.
  - The dock gets stuck in a failed state where high-speed ports do not reconnect.
- **Files**:
  - `nixos/hosts/zenbook/kernel.nix` — Enable Alt Mode drivers
  - `nixos/hosts/zenbook/hardware/hardware-configuration.nix` — Load `ps883x` and `pmic_glink_altmode` in initrd
  - `nixos/hosts/zenbook/hardware/pd-mapper.nix` — Fix systemd condition guard
- **Test**: After rebooting, check if `/sys/bus/thunderbolt/devices` registers the Barlow Ridge controller, and if `lsusb -t` shows the VIA Hub and Realtek NIC connected.

---

### Issue 10: Battery manager PMIC-glink uevent failure

- [x] **Status**: Resolved (Verified working on Ubuntu via manual post-boot ADSP remoteproc startup; battery capacity and charging status are reported correctly)
- **Severity**: P2 — Battery capacity not readable, upower reports NaN
- **Symptom**: All four power supply devices fail during early boot:
  ```
  qcom-battmgr-ac: uevent: failed to send synthetic uevent: -11
  qcom-battmgr-bat: uevent: failed to send synthetic uevent: -11
  qcom-battmgr-usb: uevent: failed to send synthetic uevent: -11
  qcom-battmgr-wls: uevent: failed to send synthetic uevent: -11
  ```
  Battery capacity returns empty. `Not charging` reported despite AC connected.
- **Root Cause**: The ADSP (`remoteproc0`) firmware (`qcadsp8380.mbn`) tries to load during
  early boot (around 1.1s) before the root filesystem is mounted, resulting in a `-2`
  (ENOENT) error. Because ADSP remains offline, the `pmic-glink` battery manager (`battmgr`)
  cannot establish communication, causing the uevent failures and empty capacity.
- **Fix**: Start the ADSP remoteproc device manually once the rootfs is mounted:
  ```bash
  echo start | sudo tee /sys/class/remoteproc/remoteproc0/state
  ```
  For a permanent fix in NixOS:
  1. Build `qcom_q6v5_pas` as a module and load it late, OR
  2. Bundle the ADSP firmware in the initrd (e.g. `boot.initrd.firmware`), OR
  3. Run a post-boot systemd service/udev rule that triggers `echo start` to the remoteproc device.
- **Test**:
  ```bash
  cat /sys/class/power_supply/qcom-battmgr-bat/capacity  # Returns actual percentage
  upower -i /org/freedesktop/UPower/devices/battery_BAT0  # Shows capacity and charging state
  ```

---

### Issue 11: SoundWire controller error storm

- [x] **Status**: Resolved (Speakers functional. Boot-time FIFO errors mitigated by `softdep snd-soc-wsa884x pre: qcom_q6v5_pas` in modprobe config to improve load ordering)
- **Severity**: P2 — Continuous errors every 2–5 seconds, CPU overhead
- **Symptom**: Continuous errors in dmesg:
  ```
  qcom-soundwire 6b10000.soundwire: SWR CMD error, fifo status 0x4e00c00f, flushing fifo
  ```
- **Root Cause**: The WSA884x speaker amplifier codec and the SoundWire bus controller
  cannot negotiate because they require the Audio DSP (ADSP) to be online. Since the
  ADSP failed to load its firmware during early boot, the SoundWire bus entered an
  error loop.
- **Fix**: Start the ADSP remoteproc device post-boot (same as Issue 10). Once ADSP is online, SoundWire binds successfully and audio playback works.
- **Test**:
  ```bash
  aplay -l  # Lists audio devices
  speaker-test -c 2  # Verify speaker playback
  ```

---

### Issue 12: Missing kernel modules (cpufreq_schedutil, nf_nat_ftp)

- [x] **Status**: Resolved (`schedutil` is built-in `=y`, not a loadable module)
- **Severity**: P3 — Suboptimal CPU frequency scaling, no FTP NAT
- **Symptom**:
  ```
  systemd-modules-load: Failed to find module 'cpufreq_schedutil'
  systemd-modules-load: Failed to find module 'nf_nat_ftp'
  ```
- **Root Cause**: `cpufreq_schedutil` is compiled **built-in**
  (`CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`) — it is NOT a loadable module.
  The `systemd-modules-load` error is cosmetic and expected. The `schedutil`
  governor is confirmed active on all 12 cores. `nf_nat_ftp` is still missing
  if FTP NAT is needed.
- **Fix**: `schedutil` requires no fix (built-in). For `nf_nat_ftp`, add to `kernel.nix` configurePhase if FTP NAT is needed:
  ```nix
  ./scripts/config --module NF_NAT_FTP
  ```
- **Test**:
  ```bash
  cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor  # Should say 'schedutil'
  lsmod | grep cpufreq
  ```

---

### Issue 13: No swap configured (30 GiB RAM, zero swap)

- [x] **Status**: ✅ Resolved — verified on Gen 1 (2026-06-06).
      `zram0` active at 30.7 GiB with zstd compression.
- **Severity**: P1 — OOM risk under heavy workloads
- **Symptom**: `free -h` showed 0 B swap. 30 GiB RAM with no swap.
- **Root Cause**: `CONFIG_ZRAM` was missing from the custom kernel.
- **Fix**: Added `CONFIG_ZRAM=m` and `CONFIG_ZRAM_DEF_COMP_ZSTD=y`
  to `kernel.nix`, plus `zramSwap` config in `power.nix`.
- **Verified**:
  ```
  zram0  30.7G  disk  swap  zram0  [SWAP]
  ```

---

### Issue 14: `efi=noruntime` blocks fwupd firmware updates

- [x] **Status**: Resolved. Verified `efibootmgr` and `fwupdmgr` can read and write
      variables (e.g. bootloader timeout written successfully). `efi=noruntime` has
      been permanently removed from default boot arguments and the specialisation
      cleaned up.
- **Severity**: P1 — Firmware is 6 months stale
- **Symptom**: `efibootmgr` not found. `fwupd` can list devices.
- **Root Cause**: `efi=noruntime` in kernel params. Reads work but
  write operations (capsule updates) may be blocked.
- **Fix**: `efi-runtime-test` specialisation boot entry present.
  Also need to add `efibootmgr` to system packages.
- **Test**:
  ```bash
  # Boot into efi-runtime-test specialisation, then:
  ls /sys/firmware/efi/efivars/ | wc -l
  sudo fwupdmgr get-updates
  ```

---

### Issue 15: AppArmor not active — missing from LSM cmdline

- [x] **Status**: ✅ Resolved
- **Severity**: P1 — Security policy not enforced
- **Symptom**: `cat /sys/kernel/security/lsm` shows only `capability`.
  `cat /sys/module/apparmor/parameters/enabled` returns `N`.
  `aa-status` not found.
- **Root Cause**: The AppArmor config `config/security/apparmor/default.nix`
  was completely orphaned and never imported by the SOE.
- **Fix**: Refactored AppArmor config to separate enablement from policies.
  Created `soe/security/apparmor/default.nix` (imported by `soe/security/default.nix`)
  which correctly sets `security.apparmor.enable = true` and `security.lsm = [ "apparmor" ]`.
- **Test**:
  ```bash
  cat /sys/kernel/security/lsm          # Should include apparmor
  cat /sys/module/apparmor/parameters/enabled  # Should be Y
  sudo aa-status                        # Should list profiles
  ```

---

### Issue 16: Thunderbolt 5 dock drops to USB 2.0 full-speed

- [/] **Status**:
  - Blocked on upstream kernel patches.
  - Major patches to decouple the Thunderbolt subsystem from PCIe and add USB4 PHY programming.
  - These were submitted in May 2026 and are currently under review.
- **Severity**: P1 — No dock ethernet, no DP alt-mode
- **Symptom**: Razer TB5 Dock (1532:0f53) enumerates on USB bus 5
  as full-speed. The entire USB tree disconnects at t=17s then
  reconnects at t=19s as full-speed (USB 1.1). No Thunderbolt
  domains register (`/sys/bus/thunderbolt/devices/` is empty).
  Dock ethernet (`enu1u4u1`) does not appear.
- **Root Cause**:
  - ADSP starting `pmic_glink_altmode` triggers Type-C lane renegotiation.
  - Native Thunderbolt 5 tunneling is structurally impossible right now.
  - The Snapdragon X Elite USB4 Host Router is an integrated platform device.
  - But the Linux `thunderbolt` subsystem currently assumes all Host Routers are PCIe devices.
  - Furthermore, the `qcom,x1e80100-usb4-hr` (Host Router) device tree node is completely absent from `linux-next`.
  - Because no Host Router binds, the dock eventually times out during Alt Mode negotiation and drops back to USB 2.0 Billboard fallback mode.
- **dmesg sequence**:
  ```
  t=15s  usb 5-1.5: new full-speed (dock first enum)
  t=17s  usb 5-1: USB disconnect (entire hub tree drops)
  t=19s  usb 5-1.5: new full-speed (dock re-enums as USB 1.1)
  ```
- **Workaround**: Use USB-to-Ethernet adapter (`usb-to-eth`,
  `enu2c2` at 10.10.1.90) as primary network path.
- **Upstream Tracking (May 2026)**: Look out for these patch series merging into mainline:
  - `[PATCH v5 0/4] Prepwork for non-PCIe NHI/TBT hosts` (Refactors `tb_nhi` away from `pci_device`)
  - `[PATCH 0/5] USB4 mode programming for QMMPHY on X1E` (Adds physical layer USB4 configurations)
  - `[PATCH RFC] dt-bindings: thunderbolt: Add Qualcomm USB4 Host Router` (Adds `qcom,x1e80100-usb4-hr` dt-bindings)

---

### Issue 17: Home Manager fails — opnix token unreadable

- [x] **Status**: ✅ Resolved
- **Severity**: P2 — HM activation blocked, opnix secrets missing
- **Symptom**: `home-manager-mahdtech.service` fails with:
  ```
  ERROR: Cannot read system token at /etc/opnix-token
  INFO: Make sure the system token can be accessed by your user
  ```
- **Root Cause**: `/etc/opnix-token` has permissions
  `-rw-r----- root onepassword-secrets`. The `mahdtech` user IS in
  group `onepassword-secrets` (993), but HM runs as a systemd
  service which may not have supplementary groups loaded at
  activation time (early boot, before user session).
- **Also**: `pgrep: command not found` during HM activation
  (procps missing from system packages).
- **Fix**: Added `onepassword-secrets` to `SupplementaryGroups`
  for `home-manager-mahdtech` service. Added `procps` to SOE
  `environment.systemPackages`.

---

### Issue 18: pmic_glink uevent failures

- [ ] **Status**: Open — cosmetic but may indicate deeper issue
- **Severity**: P3 — Low (battery still works)
- **Symptom**: `synth uevent: failed to send uevent` for
  `qcom-battmgr-ac`, `qcom-battmgr-bat`, `qcom-battmgr-usb`,
  `qcom-battmgr-wls` power supply devices.
- **Root Cause**: uevent delivery fails during PMIC GLINK init,
  possibly due to userspace not ready or netlink buffer overflow.
  Battery status/capacity still functional via sysfs.
- **Impact**: udev rules that depend on power supply events may
  not fire. Battery notifier timer should still work.

---

## Resolved Issues

_Items moved here after testing confirms the fix._

---

## Test Results Log

### 2026-06-06 — Gen 1 Fresh Install Audit

Fresh NixOS install via nixos-anywhere. Partition layout:
ESP (1G) / pstore (16M, raw) / btrfs root (953G, subvols: root, home, nix).

| Check         | Status | Detail                                     |
| ------------- | ------ | ------------------------------------------ |
| Kernel        | ✅     | `7.1.0-rc5-next-20260528`                  |
| Ramoops       | ✅     | `0x200000@0xb7000000, ecc: 0` — no errors  |
| Netconsole    | ✅     | Active, `10.10.1.90 → 10.10.1.93:6666`     |
| pstore-blk    | ✅     | Partition exists, label `disk-main-pstore` |
| ZRAM swap     | ✅     | `zram0 30.7G` active                       |
| SSH hardening | ✅     | password=no, root=no, kbd=no               |
| Boot editor   | ✅     | `editor 0`                                 |
| opnix token   | ✅     | Present, 853 bytes, correct group          |
| CPU governor  | ✅     | `schedutil`                                |
| Remoteprocs   | ✅     | ADSP + CDSP running                        |
| WiFi          | ✅     | ath12k firmware loaded (wcn7850 hw2.0)     |
| Display       | ✅     | card0: eDP-1, DP-1, DP-2, HDMI-A-1         |
| Battery       | ⚠️     | Status works, `capacity` sysfs missing     |
| AppArmor      | ❌     | Kernel compiled but not in LSM cmdline     |
| TB5 Dock      | ❌     | Drops to USB 2.0, no tunnel                |
| Home Manager  | ❌     | opnix token read failure                   |
| Thermals      | ✅     | 29-30°C idle                               |

### 2026-06-05 — Fullscreen Stress Tests (Wayland / Native 3K Resolution)

We successfully verified the system under maximum CPU and GPU stress
for 20 minutes continuously on Ubuntu, confirming absolute
power/thermal stability on this kernel.

#### Baseline Performance Results (Ubuntu 26.04)

We ran a combined **12-core CPU stress + Vulkan GPU stress** test
for 60 seconds at native **3072x1920** fullscreen resolution to
establish a performance baseline:

- **GPU Vulkan Score (`vkmark`)**: `3735` (4-second duration per
  scene, run fullscreen under 100% 12-core CPU load).
  - _Note_: Without background CPU load, the standalone fullscreen
    score is `5884`.
- **CPU Stress-ng Metrics (`stress-ng --cpu 12`)**: `4633.54` bogo
  ops/sec.

This establishes our baseline to ensure we get comparable results
under NixOS.

### 2026-06-04 — test-gpu.sh at 390 MHz GPU cap

| Test                                   | Result   | Details                              |
| -------------------------------------- | -------- | ------------------------------------ |
| glxgears (vblank_mode=0, fullscreen)   | ✅ Pass  | 3000-3500 FPS                        |
| vkcube (XCB WSI, default present)      | 🟡 Blank | Window opens, no render              |
| vkmark (immediate present, fullscreen) | 🔴 Crash | `ErrorDeviceLost`                    |
| vulkaninfo --summary                   | ✅ Pass  | Adreno X1-85, Turnip, Vulkan 1.4.348 |

### 2026-06-04 — Native kernel build crash

| Test                                          | Result    | Details                       |
| --------------------------------------------- | --------- | ----------------------------- |
| `nixos-upgrade` (native aarch64 kernel build) | 🔴 Reboot | Hard reset during compilation |

---

## Deployment Plan

> [!IMPORTANT]
> **Current state**: Gen 5 (next-20260605 upgrade). Confirmed that running GPU
> uncapped at 1.25 GHz or even 550 MHz causes PMIC overcurrent resets under
> Vulkan load. GPU is now capped at 390 MHz for stability. EFI runtime is
> permanently enabled. Now debugging Thunderbolt 5 dock.

### Next Steps

- [x] Verify ramoops: ✅ `ecc: 0`, `0x200000@0xb7000000`
- [x] Verify netconsole: ✅ active, logging to `10.10.1.93:6666`
- [x] Verify pstore-blk partition: ✅ `disk-main-pstore` 16M
- [x] Verify zram swap: ✅ `zram0 30.7G`
- [x] Verify SSH hardening: ✅ password auth disabled, root disabled
- [x] Verify opnix token: ✅ present with correct permissions
- [x] Verify boot editor disabled: ✅ `editor 0`
- [x] Fix AppArmor LSM cmdline (Issue 15)
- [ ] Investigate TB5 dock full-speed fallback (Issue 16)
- [x] Fix Home Manager opnix read failure (Issue 17)
- [x] Test efi-runtime-test specialisation (Issue 14)
- [ ] Controlled panic test to verify full capture pipeline
- [x] Verify netconsole receiver on JONS

---

## Platform Context

### Known Upstream Limitations (not fixable in this config)

- **System-wide power regulation** — hard reboots under sustained
  CPU OR GPU load. PMIC overcurrent/brownout triggers hardware
  reset. Root cause: device tree doesn't fully describe power supply
  relationships for x1e80100.
- **GPU dummy regulators** (`vdd`/`vddcx`) — DT doesn't describe
  GPU power supplies. Tracked upstream in QCOM DTS.
- **GPU clock controller sync_state()** — `gpucc` and `gcc` can't
  finalize due to GMU not fully probing.
- **PCIe dummy regulators** (`vdda`/`vddpe-3v3`) — DT doesn't
  describe PCIe regulator supplies.
- **I2C HID dummy regulators** — touchpad/keyboard `vdd`/`vddl`
  not in DT. Devices functional.
- **WCN7850 WiFi dummy regulator** — `vddio1p2` not in DT. WiFi
  functional.
- **`*_ignore_unused` boot params** — necessary until DT power
  descriptions mature.

### Working Hardware

- ✅ GPU — OpenGL 4.6 (up to 1.25 GHz, capped for stability)
- ✅ GPU — Vulkan 1.4.348 via Turnip
- ✅ Display (eDP-1 + DP-1, DP-2, HDMI-A-1)
- ✅ WiFi (ath12k/WCN7850)
- ✅ NVMe (PCIe, btrfs with subvols)
- ✅ Audio (x1e80100 codec via ADSP)
- ✅ USB-C (PD, UCSI)
- ✅ Keyboard/Touchpad (I2C HID)
- ✅ Thermals (29-30°C idle)
- ✅ Crash capture — ramoops + netconsole + pstore-blk
- ✅ Swap — zram 30.7G active
- ✅ Battery — status and energy readings working
- ✅ Boot (systemd-boot, editor disabled, efi-runtime-test entry)
- ✅ AppArmor — active in LSM command line and verified working
- ❌ Thunderbolt 5 Dock — drops to USB 2.0 full-speed
- 🔴 Stability — hard reboots under sustained CPU or GPU load
