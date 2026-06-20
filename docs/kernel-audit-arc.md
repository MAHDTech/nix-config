# Kernel Audit: Arc

## 1. Kernel Tracking

The `arc` host does **not** track the default NixOS stable kernel (`pkgs.linuxPackages`). Instead, it dynamically tracks the **latest available kernel branch**.
In [default.nix](file:///boot/nixos/nix-config/nixos/system/soe/boot/default.nix)
(which `arc` imports), `boot.kernelPackages` is configured to iterate over
`pkgs.linuxKernel.packages` and dynamically select the latest compatible
version (which is currently the 7.1.x series).

## 2. Current Kernel Version and Applied Configurations

- **Current Kernel Version:** Tracks the latest compatible kernel (evaluating to the **7.1.x** series based on the dynamic selector).
- **Kernel Parameters & Configurations Applied:**
  - **General:** `mitigations=off`, `threadirqs`; `nohibernate`, `quiet`.
  - **AMD GPU:** `amdgpu.gpu_recovery=1`, `amdgpu.si_support=1`, `amdgpu.cik_support=1`.
  - **Intel Xe:** The `xe.enable_preemption=1` parameter is currently _commented out_ as a workaround for Mesa 25.x Vulkan swapchain acquisition bugs on Battlemage.
  - **Environment Variables:** `MESA_VK_WSI_PRESENT_MODE="immediate"` is forced to mitigate swapchain crashes on the Intel Arc B580.

## 3. Key Hardware

- **CPU:** AMD Ryzen Desktop (`common-cpu-amd`, `common-cpu-amd-pstate`).
- **GPU 1 (Primary Display):** AMD APU.
- **GPU 2 (Compute/Offload):** Intel ARC B580 Battlemage dGPU (`xe` driver).
- **Storage:** BTRFS RAID 0 across 2 NVMe drives (managed via Disko).

## 4. Linux Kernel 7.1.1 Impact & Changes

### Improvements to Expect:

- **Ryzen CPU:** Better power efficiency and performance scaling thanks to AMD pstate Dynamic EPP.
- **AMDGPU:** Smoother primary display rendering with lower latency due to the AMDGPU retry loop fixes.
- **Intel Arc:** Greater overall stability for Battlemage compute/offload tasks via `xe` driver maturity.

### What Might Break:

- The dynamic move to the newest `xe` driver code could introduce brief regressions for Battlemage.
- Changes to AMDGPU's retry loop in 7.1.1 might conflict with the manually applied `amdgpu.gpu_recovery=1` parameter, potentially causing display hangs instead of clean recoveries.

### Required Changes to Nix Configuration:

We should drop the legacy workarounds:

1. **Restore Preemption:** Re-enable `xe.enable_preemption=1` in `boot.kernelParams` in `system/config/video/intel/default.nix`.
2. **Drop Present Mode Hack:** Remove the `MESA_VK_WSI_PRESENT_MODE = "immediate"` environment variable in the Intel config.
3. **Review AMD Recovery:** Consider dropping `amdgpu.gpu_recovery=1` from `system/config/video/amd/default.nix` to see if the native 7.1.1 retry loop handles hangs more gracefully.
