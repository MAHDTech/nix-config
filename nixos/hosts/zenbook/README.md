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

> [!NOTE]
> All **fully resolved issues** (Issues 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
> 15, 17, 18, and 20) have been archived in [resolved_issues.md](resolved_issues.md)
> to keep this main issue tracker focused and actionable.

---

## Open & In-Progress Issues

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
