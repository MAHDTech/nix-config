# Kernel Audit: Jons

## 1. Current Kernel Tracking

The `jons` host **does not** track the default NixOS stable kernel (`pkgs.linuxPackages`). Instead, it dynamically targets the latest compatible branch.
In `../../system/soe/boot/default.nix`, the `kernelPackages` attribute is
determined by filtering `pkgs.linuxKernel.packages` for the **latest
available Linux kernel that has a working, non-broken ZFS module**.

## 2. Kernel Version and Configurations

Because of the dynamic ZFS compatibility filter, the exact kernel version is
whatever the latest ZFS-supported kernel in nixpkgs is at evaluation time
(effectively `linuxPackages_latest`, bounded by ZFS support).

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

## 4. Linux Kernel 7.1.1 Impact & Changes

### Improvements:

- The continued maturation of the Intel `xe` driver in the 7.1 cycle will directly improve stability and performance for the Intel Arc B580 Battlemage GPU.
- The new native NTFS driver will vastly improve I/O performance for external Windows drives.

### What might break:

- Because `jons` relies on ZFS, the transition to the 7.1.x kernel series
  might be slightly delayed until OpenZFS officially tags support for it. If it
  updates too early, there is a minor risk of ZFS regressions.

### Nix Config Changes Needed:

With the 7.1.1 kernel's updated `xe` driver and the host's move to Mesa 26.x, we should re-test Vulkan apps (like Zed) and consider:

1. Dropping the `MESA_VK_WSI_PRESENT_MODE = "immediate"` workaround.
2. Re-enabling `xe.enable_preemption=1` in `boot.kernelParams`.
