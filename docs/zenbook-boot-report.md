# Zenbook A14 (Snapdragon X Elite) Boot Research Report

**Status**: 🛠️ DRAFT / FINAL RESEARCH COMPILATION
**Date**: 2026-04-07

## 1. Executive Summary
This report identifies the critical configuration requirements and BIOS settings necessary to
successfully boot NixOS on the ASUS Zenbook A14 (UX3407) Snapdragon X Elite platform.
The primary reason for previous boot failures is identified as missing Device Tree Blob (DTB)
management in the bootloader and incorrect BIOS security settings.

## 2. BIOS Configuration (Insyde BIOS)
To enable USB booting on the Zenbook A14, the following BIOS settings are **MANDATORY**:

- **BIOS Setup**: Press and hold **F2** immediately after power-on.
- **One-Time Boot Menu**: Press and hold **Esc** immediately after power-on.
- **Advanced Mode**: Press **F7** inside the BIOS to access the full range of settings.
- **Secure Boot**: Must be **[Disabled]**.
    - *Path*: Security -> Secure Boot -> Secure Boot Control.
- **Fast Boot**: Must be **[Disabled]** in the Boot tab.
- **USB Port Priority**: Use the **USB-C** ports on the left/right. The USB-A port may lack early boot driver support in the UEFI phase.
- **BitLocker**: **Suspend Protection** in Windows before making these changes to avoid recovery lockouts.

## 3. Partition & EFI Layout
The Snapdragon X Elite platform requires a modern GPT partition table and a specific EFI System Partition (ESP) layout:

- **Partition Table**: **GPT** (Mandatory). MBR is not supported.
- **ESP (EFI System Partition)**:
    - **Size**: 512MB - 1GB (Recommended).
    - **Filesystem**: **FAT32** (Mandatory).
    - **GUID**: `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`.
- **Root Partition**:
    - **Filesystem**: `ext4` or `btrfs`.
    - **GUID**: `0FC63DAF-8483-4772-8E79-3D69D8477DE4`.

## 4. Kernel & Bootloader Strategy (The "Magic Sauce")
Unlike x86, the Zenbook A14 requires an explicit Device Tree Blob (DTB) to be passed by the bootloader.

### Bootloader: systemd-boot
The loader entry (`/loader/entries/nixos.conf`) **MUST** include the `devicetree` keyword:

```text
title NixOS Zenbook Installer
linux /nixos/kernel
initrd /nixos/initrd
devicetree /nixos/dtb
options init=/nix/store/.../init clk_ignore_unused pd_ignore_unused earlyprintk arm64.nopauth
```

- **Kernel**: Must be a "Concept" or "Next" kernel (e.g., based on `jhovold` or `linux-next`) with Snapdragon X Elite patches.
- **DTB**: The correct blob for this hardware is `qcom/x1e80100-asus-zenbook-a14.dtb`.

### Boot Strategy Comparison (Ubuntu vs NixOS)
Ubuntu's Snapdragon Concept succeeds because its GRUB is pre-patched to automatically select and fix up the DTB. NixOS images must manually bundle and point to this DTB in the `systemd-boot` config.

## 5. Summary of Facts
1. **Fact**: Standard AArch64 ISOs will fail without the Zenbook-specific DTB.
2. **Fact**: Secure Boot must be OFF.
3. **Fact**: The bootloader must explicitly pass the DTB relative to the ESP root.
4. **Fact**: USB-C ports are the most reliable for booting.
