# ASUS Zenbook A14 — Resolved Issues Archive

This archive contains detailed documentation for issues that have been successfully resolved on the Zenbook host.

---

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

---

### Issue 9: Razer Thunderbolt 5 Dock Ethernet regression (USB disconnect / Alt Mode negotiation failure)

- [x] **Status**: Resolved via Workaround
  - Enforced `module_blacklist=qcom_q6v5_pas` globally in `hardware-configuration.nix` kernel parameters.
  - The dock now successfully falls back to stable USB 2.0 High-Speed mode,
  - bringing up the Realtek Gigabit Ethernet adapter and USB hubs reliably.
- **Severity**: P0 — High-speed dock peripherals and Ethernet not detected
- **Symptoms**:
  - The Razer TB5 Dock USB tree initializes during early boot but is disconnected as soon as the ADSP remoteproc boots and `pmic-glink` initiates Type-C port manager negotiation.
  - High-speed USB hub and Realtek Gigabit NIC fail to reconnect on the installed OS, but work perfectly at USB 2.0 speed (480 Mbps) on the installer.
- **Root Cause**:
  - **The Installer Fallback:** The installer blacklists `qcom_q6v5_pas` (ADSP) to
    prevent boot hangs. Since ADSP is offline, the Type-C port manager
    (`pmic_glink_altmode` / `ucsi_glink`) never runs, and Alt Mode negotiation is
    skipped. The hardware link defaults to a stable **USB 2.0 High-Speed
    Fallback mode** (480 Mbps), where the dock's Realtek RTL8153 Ethernet
    adapter is exposed and functional.
  - **The Installed OS Alt Mode Failure:** On the installed OS, ADSP runs and
    triggers Alt Mode negotiation. However, because the Parade PS883X retimer
    driver (`ps883x`) is loaded too late (stage 2 instead of initrd stage 1)
    and the kernel lacks device-tree bindings for the integrated Snapdragon X
    Elite USB4 Host Router, Alt Mode negotiation fails. The connection resets,
    and the dock drops to **USB 1.1 Billboard mode** (12 Mbps), completely
    disconnecting high-speed hubs and Ethernet.
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
- **Root Cause**: The ADSP (`remoteproc0`) firmware (`qcadsp8380.mbn`) tries to
  load during early boot (around 1.1s) before the root filesystem is mounted,
  resulting in a `-2` (ENOENT) error. Because ADSP remains offline, the
  `pmic-glink` battery manager (`battmgr`) cannot establish communication,
  causing the uevent failures and empty capacity.
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
- **Root Cause**: The WSA884x speaker amplifier codec and the SoundWire bus
  controller cannot negotiate because they require the Audio DSP (ADSP) to be
  online. Since the ADSP failed to load its firmware during early boot, the
  SoundWire bus entered an error loop.
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
  (`CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`) — it is NOT a loadable module. The
  `systemd-modules-load` error is cosmetic and expected. The `schedutil`
  governor is confirmed active on all 12 cores. `nf_nat_ftp` is still missing if
  FTP NAT is needed.
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

- [x] **Status**: ✅ Resolved — verified on Gen 1 (2026-06-06). `zram0` active at 30.7 GiB with zstd compression.
- **Severity**: P1 — OOM risk under heavy workloads
- **Symptom**: `free -h` showed 0 B swap. 30 GiB RAM with no swap.
- **Root Cause**: `CONFIG_ZRAM` was missing from the custom kernel.
- **Fix**: Added `CONFIG_ZRAM=m` and `CONFIG_ZRAM_DEF_COMP_ZSTD=y` to `kernel.nix`, plus `zramSwap` config in `power.nix`.
- **Verified**:
  ```
  zram0  30.7G  disk  swap  zram0  [SWAP]
  ```

---

### Issue 14: `efi=noruntime` blocks fwupd firmware updates

- [x] **Status**: Resolved. Verified `efibootmgr` and `fwupdmgr` can read and
      write variables (e.g. bootloader timeout written successfully).
      `efi=noruntime` has been permanently removed from default boot arguments and
      the specialisation cleaned up.
- **Severity**: P1 — Firmware is 6 months stale
- **Symptom**: `efibootmgr` not found. `fwupd` can list devices.
- **Root Cause**: `efi=noruntime` in kernel params. Reads work but write operations (capsule updates) may be blocked.
- **Fix**: `efi-runtime-test` specialisation boot entry present. Also need to add `efibootmgr` to system packages.
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
- **Symptom**: `cat /sys/kernel/security/lsm` shows only `capability`. `cat /sys/module/apparmor/parameters/enabled` returns `N`. `aa-status` not found.
- **Root Cause**: The AppArmor config `config/security/apparmor/default.nix` was completely orphaned and never imported by the SOE.
- **Fix**: Refactored AppArmor config to separate enablement from policies.
  Created `soe/security/apparmor/default.nix` (imported by
  `soe/security/default.nix`) which correctly sets `security.apparmor.enable =
true` and `security.lsm = [ "apparmor" ]`.
- **Test**:
  ```bash
  cat /sys/kernel/security/lsm          # Should include apparmor
  cat /sys/module/apparmor/parameters/enabled  # Should be Y
  sudo aa-status                        # Should list profiles
  ```

---

### Issue 17: Home Manager fails — opnix token unreadable

- [x] **Status**: ✅ Resolved
- **Severity**: P2 — HM activation blocked, opnix secrets missing
- **Symptom**: `home-manager-mahdtech.service` fails with:
  ```
  ERROR: Cannot read system token at /etc/opnix-token
  INFO: Make sure the system token can be accessed by your user
  ```
- **Root Cause**: `/etc/opnix-token` has permissions `-rw-r----- root
onepassword-secrets`. The `mahdtech` user IS in group
  `onepassword-secrets` (993), but HM runs as a systemd service which may not
  have supplementary groups loaded at activation time (early boot, before user
  session).
- **Also**: `pgrep: command not found` during HM activation (procps missing from system packages).
- **Fix**: Added `onepassword-secrets` to `SupplementaryGroups` for `home-manager-mahdtech` service. Added `procps` to SOE `environment.systemPackages`.
