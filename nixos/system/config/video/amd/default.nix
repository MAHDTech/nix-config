{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    # GUI tools for AMD GPU management
    lact
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
      # Enable AMD GPU support for older architectures if needed
      # Uncomment if you have Southern Islands (SI) or Sea Islands (CIK) APUs
      # "radeon.si_support=0" "amdgpu.si_support=1"
      # "radeon.cik_support=0" "amdgpu.cik_support=1"

      # Stability parameters for Vega and newer APUs
      # Helps prevent context-switching hangs between Graphics and Compute
      "amdgpu.gpu_recovery=1"
      "amdgpu.si_support=1"
      "amdgpu.cik_support=1"
    ];
  };

  hardware = {

    amdgpu = {

      amdvlk = {
        enable = true;
        support32Bit.enable = true;
        supportExperimental.enable = false;
        settings = { };
      };

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

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        # Linux firmware collection
        linux-firmware

        # Mesa 3D graphics library
        mesa

        # AMD Video Processing Library GPU runtime for hardware video processing
        vpl-gpu-rt

        # Vulkan loader for graphics APIs
        vulkan-loader

        # OpenCL support for AMD GPUs
        rocmPackages.clr.icd

        # Additional Mesa packages for better compatibility
        mesa.llvmPackages.libclang
      ];

      enable32Bit = true;
      extraPackages32 = with pkgs; [
        # Linux firmware collection (32-bit)
        linux-firmware

        # AMD Video Processing Library GPU runtime (32-bit)
        vpl-gpu-rt

        # Vulkan loader for graphics APIs (32-bit)
        vulkan-loader
      ];
    };
  };

  services.xserver = {
    videoDrivers = [
      "amdgpu"
    ];
  };

  # LACT daemon for GPU management
  systemd = {
    packages = with pkgs; [ lact ];
    services.lactd.wantedBy = [ "multi-user.target" ];
    # HIP support for compute workloads (Blender, etc.)
    tmpfiles.rules =
      let
        rocmEnv = pkgs.symlinkJoin {
          name = "rocm-combined";
          paths = with pkgs.rocmPackages; [
            rocblas
            hipblas
            clr
          ];
        };
      in
      [
        "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
      ];
  };

  environment.variables = {
    # Sets the default driver for VA-API, "amdgpu" is used for AMD GPUs
    LIBVA_DRIVER_NAME = "amdgpu";

    # Ensures legacy VDPAU applications can use VA-API for acceleration
    VDPAU_DRIVER = "va_gl";

    # Ensures X11 applications use Mesa's OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = "mesa";

    # General performance enhancement for Vulkan applications by caching pipelines
    ANV_ENABLE_PIPELINE_CACHE = "1";

    # Allows Mesa's threaded optimizations for better performance, especially in CPU-bound games
    __GL_THREADED_OPTIMIZATIONS = "1";

    # Force RADV over AMDVLK for better performance in games
    AMD_VULKAN_ICD = "RADV";

    # Enable ROCm for pre-Vega APUs if needed
    # ROC_ENABLE_PRE_VEGA = "1";

    # Additional performance optimizations
    MESA_GL_VERSION_OVERRIDE = "4.5";
    MESA_GLSL_VERSION_OVERRIDE = "450";
  };

}
