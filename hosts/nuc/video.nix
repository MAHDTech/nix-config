{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    glxinfo
    intel-gpu-tools
    intel-graphics-compiler
    intel-media-sdk
    intel-ocl
    inteltool
    libva-utils
    linux-firmware
    mesa
    vaapi-intel-hybrid
    vaapiVdpau
    vdpauinfo
  ];

  boot.initrd.kernelModules = ["i915"];

  boot.blacklistedKernelModules = ["nouveau" "nvidia"];

  # https://dgpu-docs.intel.com/devices/hardware-table.html
  # https://nixos.wiki/wiki/Intel_Graphics
  # https://wiki.gentoo.org/wiki/Intel#Feature_support
  # https://nixos.wiki/wiki/Accelerated_Video_Playback
  # https://wiki.archlinux.org/title/Intel_graphics#Enable_GuC_/_HuC_firmware_loading
  # lspci -nn |grep  -Ei 'VGA|DISPLAY'
  boot.kernelParams = [
    #"i915.force_probe=5691"
    "i915.enable_guc=3"
  ];

  hardware.opengl = {
    enable = true;

    driSupport = true;
    #driSupport32bit = true;

    extraPackages = with pkgs; [
      intel-media-driver
      intel-ocl
      linux-firmware
      mesa
      vaapi-intel-hybrid
      vaapiVdpau
    ];

    extraPackages32 = with pkgs; [
      intel-media-driver
      intel-ocl
      linux-firmware
      mesa
      vaapi-intel-hybrid
      vaapiVdpau
    ];
  };

  services.xserver.videoDrivers = ["intel"];

  environment.variables = {
    VDPAU_DRIVER = "va_gl";
    LIBVA_DRIVER_NAME = "iHD";
  };
}
