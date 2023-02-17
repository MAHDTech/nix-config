{ inputs, config, lib, pkgs, ... }:

let

in {

  imports = [

  ];

  environment.systemPackages = with pkgs; [

    glxinfo

  ];

  boot.blacklistedKernelModules = [

  ];

  boot.kernelParams = [

  ];

  hardware.opengl = {

    enable = true;

    driSupport = true;

    extraPackages = with pkgs; [

    ];

  };

  #services.xserver.videoDrivers = [ "intel" ];

  environment.variables = {

    #VDPAU_DRIVER = "va_gl";
    #LIBVA_DRIVER_NAME = "iHD";

  };

}
