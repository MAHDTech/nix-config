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

---

## 2. Active Software Workarounds & Hacks

Due to the pre-production/early-stage nature of the CIX P1 UEFI firmware and kernel patches, several workarounds are in place:

### 1. SMMUv3 Event Queue Workaround (`smmu-evtq-fix.service`)

- **Location**: `hardware/smmu-fix.nix`
- **Mechanism**: Direct physical memory write (`devmem2`) to SMMU Control Register 0 (`0x0b010020`) clearing bit 2 (`EVENTQEN`) to value `0x19`.
- **Why**: The EDK2 BIOS v1.2.1 has an invalid IORT table that misconfigures the SMMUv3
  Stream ID interrupts. Without this, SMMU event queue interrupts trigger an interrupt
  storm, causing immediate `CMD_SYNC` timeouts on the NVMe controller, file system
  crashes, and kernel panics.
- **Prerequisite**: Requires `STRICT_DEVMEM` and `IO_STRICT_DEVMEM` to be disabled in the custom kernel configuration.

### 2. Clock Termination Protection (`clk_ignore_unused`)

- **Location**: `hardware/hardware-configuration.nix` (under `boot.kernelParams`)
- **Mechanism**: Kernel boot parameter `clk_ignore_unused`.
- **Why**: Prevents the generic Linux clock subsystem from disabling unused clocks initialized by UEFI before CIX-specific drivers have finished probing and claiming them.

### 3. GPU Driver Blacklisting (`module_blacklist=panfrost`)

- **Location**: `hardware/hardware-configuration.nix` (under `boot.kernelParams`)
- **Mechanism**: Explicitly blacklists the legacy `panfrost` module.
- **Why**: Prevents the kernel from trying to bind the legacy Mali `panfrost` driver to the Immortalis-G720 GPU, ensuring `panthor` takes sole control.

---

## 3. What We Are Waiting On

We are tracking the following upstream development items and firmware updates:

1. **BIOS Fix for SMMU (Radxa / CIXTech)**:
   - **Waiting For**: An updated EDK2 BIOS/UEFI firmware release containing a corrected ACPI IORT table.
   - **Action Item**: Once this is released, we can completely delete `smmu-evtq-fix.service` and re-enable kernel-level `CONFIG_STRICT_DEVMEM` / `CONFIG_IO_STRICT_DEVMEM`.
2. **HDMI/DisplayPort Audio Drivers (CIXTech)**:
   - **Waiting For**: Upstreaming of the Tensilica HiFi5 DSP IPC / Mailbox controller driver (`SND_HDA_CIX_IPBLOQ`) and corresponding firmware release to `cix-linux-main`.
   - **Action Item**: Once the code lands and audio firmware is provided, we will update the config to pull the new firmware package and load the DSP kernel module.
3. **TPM Support**:
   - **Waiting For**: Either a firmware-based TPM (fTPM) option inside the UEFI / OP-TEE secure world, or manual soldering of an SPI TPM 2.0 chip to the motherboard's open TPM header.

---

## 4. Task Tracker (Across Sessions)

- [x] Investigate early-boot NVMe timeout crash of Generation 37 (Root cause: SMMUv3 event storm triggered by display driver DMA before systemd service runs)
- [x] Shift SMMU event queue workaround into stage-1 initrd (`boot.initrd.systemd.services`)
- [x] Trigger deployment of Generation 38 (Failed to boot due to missing initrd script package)
- [x] Investigate boot failure of Generation 38 (Root cause: initrd script not in boot.initrd.systemd.storePaths)
- [x] Add initrd script to boot.initrd.systemd.storePaths
- [x] Verify NixOS configuration syntax and build ORION system configuration (Generation 32 built with modular display drivers, early stage-2 workaround, and deadlock-breaking dependencies)
- [ ] Trigger deployment on Orion host, confirm successful boot and system stability (Ready for reboot test)
