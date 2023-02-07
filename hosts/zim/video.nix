{ config, lib, nixpkgs, pkgs, ... }:

let

in {

  imports = [

  ];

  environment.systemPackages = with pkgs; [

    glxinfo

  ];

  boot.blacklistedKernelModules = [

    "nouveau"
    "nvidia"

  ];

  boot.kernelParams = [

  ];

  nixpkgs.config.packageOverrides = pkgs: {

  };

  hardware.opengl = {

    enable = true;

    driSupport = true;

    extraPackages = with pkgs; [

    ];

  };

  #services.xserver.videoDrivers = [ "CHANGE_ME" ];

  environment.variables = {

    #VDPAU_DRIVER = "va_gl";
    #LIBVA_DRIVER_NAME = "iHD";

  };

}
