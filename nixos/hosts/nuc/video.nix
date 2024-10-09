{pkgs, ...}: {
  imports = [];

  # NOTES:
  # - DisplayLink driver contains binary blobs, need to pre-fetch into store.
  #   nix-prefetch-url --name displaylink-600.zip https://www.synaptics.com/sites/default/files/exe_files/2024-05/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.0-EXE.zip
  # - Intel ARC needs kernel v6.2 or later.

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    intel-gpu-tools
    vulkan-tools
  ];

  boot = {
    initrd.kernelModules = [
      "i915"
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
      "acpi_rev_override=5"
      "i915.enable_guc=3"
      "i915.force_probe=46a6"
      "i915.force_probe=5691"
    ];
  };

  hardware = {
    graphics = {
      enable = true;

      # intel-media-driver for LIBVA_DRIVER_NAME=iHD
      # intel-vaapi-driver for LIB_DRIVER_NAME=i965

      extraPackages = with pkgs; [
        intel-compute-runtime
        intel-media-driver
        intel-ocl
        linux-firmware
        mesa
        vpl-gpu-rt
      ];

      extraPackages32 = with pkgs; [
        intel-compute-runtime
        intel-media-driver
        intel-ocl
        linux-firmware
        mesa
        vpl-gpu-rt
      ];
    };
  };

  services.xserver.videoDrivers = [
    "displaylink"
    "intel"
  ];

  environment.variables = {
    VDPAU_DRIVER = "va_gl";
    LIBVA_DRIVER_NAME = "iHD";
  };
}
