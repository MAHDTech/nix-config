{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../graphics
  ];

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    libva-utils
    nvtopPackages.full
    vulkan-tools
    mesa-demos
  ];

  boot = {
    initrd.kernelModules = [
      "xe"
    ];

    blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    kernelParams = [
      # xe.enable_preemption=1 removed: causes Vulkan swapchain acquisition
      # failures on BMG G21 (Intel Arc B580 Battlemage). The xe driver's GPU
      # preemption implementation for BMG is still immature in Mesa 25.x.

      # Disable GPU Power Management
      #"xe.runpm=0"
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    graphics.intel.enable = true;
  };

  services.xserver = {
    videoDrivers = [
      "modesetting"
    ];
  };

  environment.variables = {
    # Sets the default driver for VA-API, "iHD" is used for Intel ARC GPUs
    LIBVA_DRIVER_NAME = lib.mkDefault "iHD";

    # Ensures X11 applications use Mesa's OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = lib.mkDefault "mesa";

    # NOTE: MESA_VK_WSI_PRESENT_MODE=immediate used to be set here as a
    # workaround for the Intel Arc B580 (BMG G21) ANV Vulkan swapchain bug in
    # Mesa 25.x. environment.variables is global, so it also applied to the AMD
    # display GPU — disabling vsync for every Vulkan application on the system
    # and burning iGPU bandwidth on frames the panel discards.
    #
    # Set it per-application instead, on the applications that actually run on
    # the Arc, e.g. as a Steam launch option:
    #   MESA_VK_WSI_PRESENT_MODE=immediate DRI_PRIME=1 %command%
  };
}
