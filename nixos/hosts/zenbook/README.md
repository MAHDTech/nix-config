# ASUS Zenbook A14 — NixOS Issue Tracker

> Snapdragon X Plus (SC8380XP / x1e80100) · Adreno X1-85 · aarch64
> Kernel: linux-next `next-20260602` · Mesa 26.1.1 (freedreno) · NixOS 26.05

Work through issues **one at a time** — build, test, verify, then check off before moving on.

---

## Issues

### Issue 1: Vulkan rendering broken (vkcube blank, vkmark DEVICE_LOST)

- [ ] **Status**: Fix applied, pending rebuild and test
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
  - `scripts/test-gpu.sh` — Consider adding Wayland WSI tests (run vkcube under Wayland directly)
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

- [ ] **Status**: Not started
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

- [ ] **Status**: Not started
- **Severity**: P1 — GPU at ~31% max performance
- **Symptom**: `cat /sys/class/devfreq/3d00000.gpu/max_freq` → `390000000`
- **Root Cause**: `systemd.services.gpu-frequency-cap` in `hardware-configuration.nix`
  writes `390000000` to prevent overcurrent crashes caused by GPU dummy regulators
  (`vdd` and `vddcx` on `regulator-dummy` at 0mV/0mA). Without real PMIC-backed
  voltage scaling, high GPU clocks draw unregulated current.
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

- [ ] **Status**: Not started
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

- [ ] **Status**: Not started
- **Severity**: P2 — No crash dumps captured on hard reset
- **Symptom**: `/sys/fs/pstore/` is empty. `CONFIG_PSTORE=y` but `CONFIG_PSTORE_RAM` is not set.
- **Root Cause**: PSTORE is enabled in the kernel but `PSTORE_RAM` (ramoops) is
  not configured, and no `ramoops` reserved memory region is defined in the
  device tree. Without ramoops, kernel panics that cause hard resets leave no trace.
- **File**: `nixos/hosts/zenbook/kernel.nix` (configurePhase)
- **Fix**: Enable in kernel config:
  ```
  ./scripts/config --enable PSTORE_RAM
  ./scripts/config --enable PSTORE_CONSOLE
  ./scripts/config --enable PSTORE_PMSG
  ```
  Then add a kernel parameter for ramoops memory reservation (needs a safe address from the DT reserved regions).
- **Test**:
  ```bash
  ls /sys/fs/pstore/  # Should show ramoops backend available
  # Trigger a test: echo c > /proc/sysrq-trigger  (causes panic — DO THIS CAREFULLY)
  # After reboot, check /sys/fs/pstore/ for crash dump
  ```
- **Notes**: Finding a safe reserved memory address for ramoops on x1e80100
  requires checking the device tree for unused reserved memory regions.
  The kernel already reserves `pld-gmu@81f36000` (4 KiB) — ramoops needs
  ~2 MiB elsewhere.

---

### Issue 6: Defconfig regeneration and platform trimming

- [ ] **Status**: Not started
- **Severity**: P3 — Housekeeping
- **Symptom**: Defconfig header says `7.1.0-rc5` but kernel source is `rc6`. Many non-Qualcomm platforms enabled (Exynos, Tegra, Mediatek, etc.) increasing kernel size.
- **File**: `nixos/hosts/zenbook/files/config/zenbook.defconfig`
- **Fix**: Regenerate defconfig from the running kernel (`zcat /proc/config.gz > zenbook.defconfig`), then trim non-Qualcomm `ARCH_*` entries.
- **Test**:
  ```bash
  # Rebuild and boot — verify no regressions
  uname -a  # Same kernel version
  lsmod | wc -l  # Similar module count
  sudo dmesg | grep -i error | wc -l  # No new errors
  ```

---

### Issue 7: DSP subsystem (qcom_q6v5_pas) enablement

- [ ] **Status**: Not started
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

- [ ] **Status**: Not started
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

---

## Resolved Issues

_Items moved here after testing confirms the fix._

---

## Test Results Log

### 2026-06-04 — test-gpu.sh at 390 MHz GPU cap

| Test                                   | Result   | Details                                                         |
| -------------------------------------- | -------- | --------------------------------------------------------------- |
| glxgears (vblank_mode=0, fullscreen)   | ✅ Pass  | 3000-3500 FPS, stable for 60s                                   |
| vkcube (XCB WSI, default present)      | 🟡 Blank | Window opens but nothing renders, no crash                      |
| vkmark (immediate present, fullscreen) | 🔴 Crash | `ErrorDeviceLost` on `[vertex]` test, core dump (signal 6/ABRT) |
| glmark2 (vblank_mode=0, fullscreen)    | ⏳ TBD   | Started running, output cut off                                 |
| vulkaninfo --summary                   | ✅ Pass  | Adreno X1-85, Turnip, Vulkan 1.4.348                            |

**Key takeaways**:

- OpenGL acceleration is fully functional and stable at 390 MHz
- Vulkan driver (Turnip) initializes but **cannot render** — XCB WSI shows blank, GPU hangs under Vulkan workloads
- The 390 MHz cap prevents hard reboots but GPU still hangs on Vulkan `DEVICE_LOST`
- Need to test Vulkan under native Wayland WSI (not XWayland/XCB)

---

## Platform Context

### Known Upstream Limitations (not fixable in this config)

- **GPU dummy regulators** (`vdd`/`vddcx`) — device tree for x1e80100 doesn't describe GPU power supplies. Tracked upstream in QCOM DTS.
- **GPU clock controller sync_state()** — `gpucc` and `gcc` can't finalize due to GMU not fully probing. Related to regulator issue.
- **PCIe dummy regulators** (`vdda`/`vddpe-3v3`) — DT doesn't describe PCIe regulator supplies for controller `1c08000`.
- **I2C HID dummy regulators** — touchpad/keyboard `vdd`/`vddl` not in DT. Devices functional.
- **WCN7850 WiFi dummy regulator** — `vddio1p2` not in DT. WiFi functional.
- **`*_ignore_unused` boot params** — necessary until DT power descriptions mature.

### Working Hardware

- ✅ GPU — OpenGL 4.6 (glxgears 3000+ FPS @ 390 MHz)
- 🟡 GPU — Vulkan 1.4.348 via Turnip (initializes but rendering broken — DEVICE_LOST)
- ✅ Display (eDP-1 + 4 DP controllers)
- ✅ WiFi (ath12k/WCN7850)
- ✅ NVMe (PCIe, btrfs)
- ✅ Audio (x1e80100 codec, speaker safety interlock)
- ✅ USB-C (PD, DP alt-mode, UCSI)
- ✅ Keyboard/Touchpad (I2C HID)
- ✅ Thermals (GPU 33-34°C idle)
- ✅ Boot (systemd-boot, systemd initrd, clean reboots)
