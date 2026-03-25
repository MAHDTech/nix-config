{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
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
      # xe.enable_preemption=1 removed: causes Vulkan swapchain acquisition
      # failures on BMG G21 (Intel Arc B580 Battlemage). The xe driver's GPU
      # preemption implementation for BMG is still immature in Mesa 25.x.

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

      # Use Mesa from nixpkgs-unstable (26.x) for improved Intel Arc Battlemage
      # (BMG G21) Vulkan/ANV support. Mesa 25.2.x has swapchain acquisition bugs
      # on BMG that cause graphical corruption in wgpu-based apps (e.g. Zed).
      package = pkgsUnstable.mesa;
      package32 = pkgsUnstable.pkgsi686Linux.mesa;

      extraPackages = with pkgs; [
        # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs
        intel-compute-runtime

        # Level Zero GPU backend driver (libze_intel_gpu.so) for GPU compute workloads
        intel-compute-runtime.drivers

        # Hardware video acceleration driver for modern Intel GPUs (supports both iHD and ARC)
        intel-media-driver

        # Intel Video Processing Library GPU runtime for hardware video processing
        vpl-gpu-rt
      ];

      enable32Bit = true;
      extraPackages32 = with pkgs; [
        # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs (32-bit)
        intel-compute-runtime

        # Level Zero GPU backend driver (32-bit)
        intel-compute-runtime.drivers

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

    # Workaround for Intel Arc B580 (BMG G21) ANV Vulkan swapchain bug in Mesa 25.x.
    # "immediate" was the least-corrupt present mode in testing; mailbox/fifo both
    # trigger the swapchain acquisition failure. Remove once ANV BMG support matures.
    MESA_VK_WSI_PRESENT_MODE = "immediate";
  };
}
