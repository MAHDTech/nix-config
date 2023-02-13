{ config, lib, nixpkgs, pkgs, ... }:

let

in {

  imports = [

  ];

  environment.systemPackages = with pkgs; [

    intel-gpu-tools
    glxinfo

    # Displaylink docking station.
    displaylink

  ];

  boot.blacklistedKernelModules = [

    "nouveau"
    "nvidia"

  ];

  # https://dgpu-docs.intel.com/devices/hardware-table.html
  # https://nixos.wiki/wiki/Intel_Graphics
  # https://wiki.gentoo.org/wiki/Intel#Feature_support
  # https://nixos.wiki/wiki/Accelerated_Video_Playback
  # https://wiki.archlinux.org/title/Intel_graphics#Enable_GuC_/_HuC_firmware_loading
  # lspci -nn |grep  -Ei 'VGA|DISPLAY'
  boot.kernelParams = [

    #"i915.force_probe=5691"
    #"i915.enable_guc=3"

  ];

  nixpkgs.config.packageOverrides = pkgs: {

    vaapiIntel = pkgs.vaapiIntel.override {

      enableHybridCodec = true;

    };

  };

  hardware.opengl = {

    enable = true;

    driSupport = true;

    extraPackages = with pkgs; [

      intel-media-driver
      libvdpau-va-gl
      vaapiIntel
      vaapiVdpau
      vdpauinfo

    ];

  };

  #services.xserver.videoDrivers = [ "intel" ];

  environment.variables = {

    VDPAU_DRIVER = "va_gl";
    LIBVA_DRIVER_NAME = "iHD";

  };

}
