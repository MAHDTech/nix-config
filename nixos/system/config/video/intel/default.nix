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
        intel-compute-runtime
        intel-media-driver
        #intel-vaapi-driver
        #vaapiIntel
        intel-ocl
        linux-firmware
        mesa
        vpl-gpu-rt
        vulkan-loader
      ];

      enable32Bit = true;
      extraPackages32 = with pkgs; [
        #intel-compute-runtime
        #intel-media-driver
        #intel-vaapi-driver
        #vaapiIntel
        #intel-ocl
        #linux-firmware
        #mesa
        #vpl-gpu-rt
        #vulkan-loader
      ];
    };
  };

  services.xserver = {
    videoDrivers = [
      "intel"
    ];
  };

  environment.variables = {
    VDPAU_DRIVER = "va_gl";
    LIBVA_DRIVER_NAME = "iHD";
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
  };
}
