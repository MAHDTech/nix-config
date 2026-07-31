{ pkgs, lib, ... }:
{
  imports = [
    ../graphics
  ];

  environment.systemPackages = with pkgs; [
    # OpenCL info tool for verification
    clinfo
  ];

  boot = {
    initrd.kernelModules = [
      "amdgpu"
    ];

    blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    kernelParams = [
      # Enable AMD GPU support for older architectures if needed.
      # Only uncomment on Southern Islands (SI, GCN 1.0) or Sea Islands
      # (CIK, GCN 2.0) hardware — 2012-2013 era. They are inert on anything
      # newer, so do not enable them "just in case".
      # "radeon.si_support=0" "amdgpu.si_support=1"
      # "radeon.cik_support=0" "amdgpu.cik_support=1"

      # Stability parameters for Vega and newer APUs
      # Helps prevent context-switching hangs between Graphics and Compute
      "amdgpu.gpu_recovery=1"
    ];
  };

  hardware = {
    graphics.amd.enable = true;

    amdgpu = {
      initrd = {
        enable = true;
      };

      legacySupport = {
        enable = false;
      };

      opencl = {
        enable = true;
      };
    };
  };

  services.xserver = {
    videoDrivers = [
      "amdgpu"
    ];
  };

  environment.variables = {
    # VA-API driver for AMD GPUs. Mesa ships this as radeonsi_drv_video.so —
    # there is no amdgpu_drv_video.so, so "amdgpu" silently disables hardware
    # video decode entirely (vaInitialize fails with -1 and everything falls
    # back to CPU decoding).
    LIBVA_DRIVER_NAME = lib.mkDefault "radeonsi";

    # Ensures X11 applications use Mesa's OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = lib.mkDefault "mesa";

    # Force RADV over AMDVLK for better performance in games
    AMD_VULKAN_ICD = lib.mkDefault "RADV";

    # NOTE: deliberately NOT set here:
    #   VDPAU_DRIVER=va_gl        - radeonsi has a native VDPAU driver; va_gl
    #                               routes VDPAU through VA-API for no reason.
    #   ANV_ENABLE_PIPELINE_CACHE - ANV is the *Intel* Vulkan driver, and the
    #                               cache is on by default anyway.
    #   __GL_THREADED_OPTIMIZATIONS - NVIDIA-only, a no-op on Mesa. The Mesa
    #                               equivalent (mesa_glthread) defaults to on.
    #   MESA_{GL,GLSL}_VERSION_OVERRIDE - debug overrides, not optimisations.
    #                               They force Mesa to under-report its GL
    #                               version to every process on the system
    #                               (radeonsi does 4.6), pushing applications
    #                               onto fallback code paths.
  };
}
