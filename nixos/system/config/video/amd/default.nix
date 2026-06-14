{ pkgs, lib, ... }:
{
  imports = [ ];

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

  environment.variables = {
    # Sets the default driver for VA-API, "amdgpu" is used for AMD GPUs
    LIBVA_DRIVER_NAME = lib.mkDefault "amdgpu";

    # Ensures legacy VDPAU applications can use VA-API for acceleration
    VDPAU_DRIVER = lib.mkDefault "va_gl";

    # Ensures X11 applications use Mesa's OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = lib.mkDefault "mesa";

    # General performance enhancement for Vulkan applications by caching pipelines
    ANV_ENABLE_PIPELINE_CACHE = lib.mkDefault "1";

    # Allows Mesa's threaded optimizations for better performance, especially in CPU-bound games
    __GL_THREADED_OPTIMIZATIONS = lib.mkDefault "1";

    # Force RADV over AMDVLK for better performance in games
    AMD_VULKAN_ICD = lib.mkDefault "RADV";

    # Enable ROCm for pre-Vega APUs if needed
    # ROC_ENABLE_PRE_VEGA = "1";

    # Additional performance optimizations
    MESA_GL_VERSION_OVERRIDE = lib.mkDefault "4.5";
    MESA_GLSL_VERSION_OVERRIDE = lib.mkDefault "450";
  };

}
