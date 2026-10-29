# Kernel Audit: Jons

## 1. Current Kernel Tracking

JONS uses the stock `pkgs.linuxPackages_7_2` package set from the locked
nixpkgs input, matching the other managed hosts and installers. The shared
selection is in `nixos/system/soe/boot/default.nix`.

## 2. Kernel Version and Configurations

The current lock resolves to Linux `7.2.13`. Updating nixpkgs tracks patch
releases within the 7.2 series. The ZFS module comes from the same kernel
package set; builds must still verify its compatibility after updates.

**Configurations/Parameters applied:**

- **General Params:** `mitigations=off`, `threadirqs`
- **AMD GPU Params:** `amdgpu.gpu_recovery=1`, `amdgpu.si_support=1`, `amdgpu.cik_support=1`
- **Intel Arc (Xe) Params:** `xe.enable_preemption=1` was explicitly removed/commented out due to Vulkan swapchain bugs on the Xe driver for BMG.
- **Modules loaded:** `kvm-amd`, `xe` (Intel Xe), `amdgpu`, `dm-snapshot`, `zfs`.
- **Blacklisted modules:** `nouveau`, `nvidia`, `nvidia_drm`, `nvidia_modeset`.
- **Overrides:** The system forces `MESA_VK_WSI_PRESENT_MODE = "immediate"` and
  overrides `hardware.graphics.package` to use `pkgsUnstable.mesa` (Mesa 26.x)
  to work around graphical corruption bugs in the B580's Vulkan/ANV driver.

## 3. Key Hardware

- **CPU:** AMD CPU (`kvm-amd`).
- **Primary GPU (Rendering):** AMD APU (Hyprland uses this to render).
- **Secondary GPU (Offload/Compute):** Intel Arc B580 Battlemage (BMG G21) discrete GPU.
- **Storage:** ZFS storage pools with NixOS booting from a Samsung USB Flash Drive (for `/boot/efi` and `/boot/nixos`).

## 4. Upgrade Validation

Build the JONS system to verify the kernel, ZFS module, initrd, and system
configuration together:

```bash
nix build .#nixosConfigurations.JONS.config.system.build.toplevel --no-link
```

A successful build does not verify hardware behavior. After booting the new
generation, check ZFS pool imports, AMD/Intel graphics, and Vulkan applications.
