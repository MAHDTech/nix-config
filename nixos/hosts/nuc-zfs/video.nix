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
    #displaylink
  ];

  boot = {
    initrd.kernelModules = [
      "i915"
      "kvm-intel"
    ];

    blacklistedKernelModules = ["nouveau" "nvidia"];

    # https://dgpu-docs.intel.com/devices/hardware-table.html
    # https://nixos.wiki/wiki/Intel_Graphics
    # https://wiki.gentoo.org/wiki/Intel#Feature_support
    # https://nixos.wiki/wiki/Accelerated_Video_Playback
    # https://wiki.archlinux.org/title/Intel_graphics#Enable_GuC_/_HuC_firmware_loading
    # lspci -nn |grep  -Ei 'VGA|DISPLAY'
    # 00:02.0 VGA compatible controller [0300]: Intel Corporation Alder Lake-P Integrated Graphics Controller [8086:46a6] (rev 0c)
    # 03:00.0 Display controller [0380]: Intel Corporation DG2 [Arc A730M] [8086:5691] (rev 08)
    kernelParams = [
      # Pre v6.2 kernel
      #"i915.force_probe=46a6"
      #"i915.force_probe=5691"
      #"i915.enable_guc=3"
      "acpi_rev_override=5"
    ];
  };

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
      vaapiIntel
      vaapiVdpau
    ];

    extraPackages32 = with pkgs; [
      intel-media-driver
      intel-ocl
      linux-firmware
      mesa
      vaapi-intel-hybrid
      vaapiIntel
      vaapiVdpau
    ];
  };

  services.xserver.videoDrivers = [
    "intel"
    #"displaylink"
  ];

  environment.variables = {
    VDPAU_DRIVER = "va_gl";
    LIBVA_DRIVER_NAME = "iHD";
  };
}
