{ pkgs, ... }:
{
  imports = [ ];

  # NOTES:
  #     - Intel ARC needs kernel v6.2 or later.

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    libva-utils
    nvtopPackages.full
    vulkan-loader
    vulkan-tools
    vulkan-validation-layers
  ];

  boot = {
    initrd.kernelModules = [
      "i915"
    ];

    blacklistedKernelModules = [
      "amdgpu"
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    # https://dgpu-docs.intel.com/devices/hardware-table.html
    # https://nixos.wiki/wiki/Intel_Graphics
    # https://wiki.gentoo.org/wiki/Intel#Feature_support
    # https://nixos.wiki/wiki/Accelerated_Video_Playback
    # https://wiki.archlinux.org/title/Intel_graphics#Enable_GuC_/_HuC_firmware_loading
    # lspci -nn |grep  -Ei 'VGA|DISPLAY'
    # Laptop
    #   00:02.0 VGA compatible controller [0300]: Intel Corporation Alder Lake-P Integrated Graphics Controller [8086:46a6] (rev 0c)
    #   03:00.0 Display controller [0380]: Intel Corporation DG2 [Arc A730M] [8086:5691] (rev 08)
    # Desktop
    #   0d:00.0 VGA compatible controller [0300]: Intel Corporation Battlemage G21 [Intel Graphics] [8086:e20b]
    kernelParams = [
      "acpi_rev_override=5"
      "i915.enable_guc=3"
    ];
  };

  hardware = {

    graphics = {
      # NOTES:
      # intel-media-driver for LIBVA_DRIVER_NAME=iHD
      # intel-vaapi-driver for LIB_DRIVER_NAME=i965

      enable = true;
      extraPackages = with pkgs; [
        # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs
        intel-compute-runtime

        # Hardware video acceleration driver for modern Intel GPUs (supports both iHD and ARC)
        intel-media-driver

        # Legacy VA-API driver for older Intel GPUs (Gen 4.5 to Gen 12)
        #intel-vaapi-driver

        # OpenCL ICD loader for Intel GPUs - supports both old and new Intel GPUs
        intel-ocl

        # Linux firmware collection including Intel GPU microcode
        linux-firmware

        # Mesa 3D graphics library with Intel drivers
        mesa

        # Intel Video Processing Library GPU runtime for hardware video processing
        vpl-gpu-rt

        # Vulkan loader for graphics APIs
        vulkan-loader
      ];

      enable32Bit = true;
      extraPackages32 = with pkgs; [
        # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs (32-bit)
        intel-compute-runtime

        # Legacy VA-API driver for older Intel GPUs (32-bit)
        #intel-vaapi-driver

        # OpenCL ICD loader for Intel GPUs (32-bit)
        intel-ocl

        # Linux firmware collection (32-bit)
        linux-firmware

        # Intel Video Processing Library GPU runtime (32-bit)
        vpl-gpu-rt

        # Vulkan loader for graphics APIs (32-bit)
        vulkan-loader
      ];
    };
  };

  services.xserver = {
    videoDrivers = [
      "modesetting"
    ];
  };

  environment.variables = {
    # Sets the default driver for VA-API, "iHD" is used for Intel ARC GPUs
    LIBVA_DRIVER_NAME = "iHD";

    # Ensures legacy VDPAU applications can use VA-API for acceleration
    VDPAU_DRIVER = "va_gl";

    # Ensures X11 applications use Mesa's OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = "mesa";

    # General performance enhancement for Vulkan applications by caching pipelines
    ANV_ENABLE_PIPELINE_CACHE = "1";

    # Allows Mesa's threaded optimizations for better performance, especially in CPU-bound games
    __GL_THREADED_OPTIMIZATIONS = "1";
  };
}
