# Radxa Orion O6 — NixOS Host Configuration & Hardware Status

This directory contains the NixOS host configuration for the Radxa Orion O6 board, powered by the CIX P1 (SKY1) 12-core Armv9.2 SoC.

---

## 1. Hardware Support & Status Matrix

- **USB-A & USB-C**
  - **Hardware Spec**: Generic USB Host Controller + Type-C PD Controller (Realtek RTS5453)
  - **Linux Driver**: `xhci-hcd`, `cdnsp-sky1`, `cdns-usbssp`, `rts5453`
  - **Status**: ✅ Working
  - **Details**: USB-A and USB-C ports are fully operational. DisplayPort Alt
    Mode is supported. Note: 4-lane DP alt-mode (required by widescreen monitors)
    electrically disables USB 3.0 speeds on the shared cable, but USB 2.0
    remains active for keyboard/mouse. Runtime PM suspend crashes are prevented.
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

### 3. USB Runtime Suspend Disablement (IRQ 60 Fix)

- **Location**: `hardware/hardware-configuration.nix` (under `services.udev.extraRules`)
- **Mechanism**: udev rules setting `power/control` to `on` for `cdnsp-sky1` and `cdns-usbssp` drivers.
- **Why**: Prevents the kernel from attempting to runtime-suspend the Cadence
  USB controller to D3 when the USB link goes down (such as switching to
  DP-only mode). In D3 with clocks gated, register access is cut off, causing
  a level-triggered interrupt loop (IRQ 60 storm / "nobody cared" crash).

### 4. USB-C Port Disablement (Widescreen Log Spam Fix)

- **Location**: `default.nix` (under `boot.postBootCommands`)
- **Mechanism**: Writing `1` directly to `/sys/bus/usb/devices/usb14-port1/disable` at boot.
- **Why**: Since widescreen monitors negotiate 4-lane DisplayPort, the USB
  3.0 lines are electrically disconnected. Disabling this port prevents the
  XHCI controller from constantly retrying connection, silences the log
  warning loop (`usb usb14-port1: Cannot enable`), and keeps system logs clean.
  A udev rule cannot be used here because the virtual port device lacks a
  `subsystem` link in sysfs, causing systemd-udevd to ignore it.

_Note: SMMU Display early boot bypass is handled via a custom device tree overlay._

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

### 5. Hyprland Boot Hang — Buffer Import Rejection

- **Severity**: 🔴 Critical
- **Symptom**: The physical display hangs on the TTY console showing `Forked systemctl...` while Hyprland runs in the background.
- **Root Cause**: The `linlon-dp` display controller driver rejects GPU-rendered framebuffers when using DRM modifiers.
- **Fix**: Disable DRM modifiers by setting `AQ_NO_MODIFIERS = "1";` and `WLR_DRM_NO_MODIFIERS = "1";` in `environment.sessionVariables`.

### 6. DisplayPort Link Training Failure (Hyprland "Stuck" Boot)

- **Severity**: 🔴 Critical
- **Symptom**: System boots to tty but appears "stuck" on `Forked systemctl, PID xxx`. Hyprland is actually running in the background but cannot render to the screen.
- **Root Cause**:
  - The DisplayPort hardware fails link training (`[drm:trilin_dp_train][ERROR]failed to trilin_dp_link_train_cr`).
  - Because of this, the `linlondp` DRM driver fails to initialize a display pipeline.
  - This leaves Hyprland without any CRTCs or DRM connectors to output to.
- **Fix**: Needs further investigation into DP PHY training, possible kernel driver patch, or different DP cable/monitor negotiation.

### 6. Widescreen USB Log Spam udev Rule Failing

- **Severity**: 🟡 Medium (Log spam)
- **Symptom**: `usb usb14-port1: Cannot enable. Maybe the USB cable is bad?` prints every 4 seconds in the kernel log.
- **Root Cause**: The udev fix `ATTR{disable}="1"` relies on a sysfs attribute that does not exist in this kernel (`/sys/bus/usb/devices/usb14-port1/disable` is missing).
- **Fix**: Rewrite the udev rule to target the `usb_port` class or use USB authorization (`authorized="0"`).

### 7. Panfrost Vulkan (`panvk`) Implementation Errors

- **Severity**: 🟡 Medium
- **Symptom**: Wayland clients (`swaync`, `hypridle`) crash or fail to initialize buffers with `VK_ERROR_INCOMPATIBLE_DRIVER` and `[sc] Failed to create a wayland buffer`.
- **Root Cause**: The experimental `panvk` driver is being loaded for the Immortalis-G720 but fails to provide a conformant Vulkan implementation.
- **Fix**: Force clients to use GLES or disable the Vulkan backend in wlroots clients.

### 8. Missing SSH Agent Socket

- **Severity**: 🟢 Low
- **Symptom**: `Error connecting to agent: No such file or directory` at shell login.
- **Root Cause**: The 1Password SSH socket at `/home/mahdtech/.1password/agent.sock` is missing.

### 9. I2C & Touchscreen Errors

- **Severity**: 🟢 Low
- **Symptom**: Errors in dmesg like `cros-ec-i2c 6-0076: Cannot identify the EC: error -28` and `Goodix-TS 2-0014: I2C communication failure: -6`.
- **Root Cause**: Physical components might be disconnected or I2C bus speeds/pinmux are incorrect in the Device Tree.

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
- [x] Trim `config.sky1-next` kernel config to remove irrelevant SoC platform drivers (Qualcomm, Tegra, Rockchip) to reduce compile time.
- [x] Resolve Early Boot USB-C Display blank screen via custom SMMU bypass DT overlay.
- [x] Resolve USB controller suspend crash (IRQ storm) on DisplayPort Alt Mode entry.
- [x] Silence widescreen USB 3.0 loop warning log spam by de-authorizing the inactive root hub.
- [x] Fix firewall netfilter match kernel config options to enable NixOS firewall.
- [x] Upgrade kernel to 6.19.14 (resolving the Netfilter/nftables UAF memory corruption boot crash).
- [x] Resolve target boot crash (udev rules mismatch) by updating DRM device matching rules for Device Tree mode.
- [x] Clean up duplicate "Linux Boot Loader" UEFI variables in NVRAM and set `boot.loader.efi.canTouchEfiVariables = false` to prevent future pollution.
- [x] Mitigate boot timing delay by configuring `systemd.network.wait-online.anyInterface = true` to skip waiting on inactive ports.

### Pending

- [ ] Disable DRM modifiers for Aquamarine/wlroots in `default.nix` to fix Hyprland boot hang.
- [ ] Move USB-C port disablement to `boot.postBootCommands` instead of the ignored udev rule.
- [ ] Fix `config-mglru.service` boot failure by enabling `CONFIG_LRU_GEN=y` in custom kernel configuration.
- [ ] Enable `CONFIG_ZRAM_BACKEND_ZSTD=y` in custom kernel configuration to resolve zramSwap warning.
- [x] Investigate rtkit lacking RT capabilities — Verified working (mahdtech has `ulimit -r` of 95; `rtkit-daemon` is active; no errors logged).
- [ ] Investigate DisplayPort Link Training failure (`failed to trilin_dp_link_train_cr`) causing Hyprland to run headless.
- [ ] Mitigate `panvk` Vulkan driver crashing Wayland clients (swaync, hypridle).
- [ ] Resolve missing 1Password SSH agent socket.
- [ ] Investigate I2C/Touchscreen errors (`cros-ec-i2c`, `Goodix-TS`).
