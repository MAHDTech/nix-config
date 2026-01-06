{ pkgs, ... }:
{
  imports = [ ];

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
    kernelParams = [
      "xe.enable_preemption=1"

      # Disable GPU Power Management
      #"xe.runpm=0"
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;

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

        # Intel Video Processing Library GPU runtime for hardware video processing
        vpl-gpu-rt
      ];

      enable32Bit = true;
      extraPackages32 = with pkgs; [
        # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs (32-bit)
        intel-compute-runtime

        # Intel Video Processing Library GPU runtime (32-bit)
        vpl-gpu-rt
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

    # Ensures X11 applications use Mesa's OpenGL implementation
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
  };
}
