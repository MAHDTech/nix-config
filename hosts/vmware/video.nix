{ inputs, config, lib, pkgs, ... }:

{

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

  services.xserver.videoDrivers = [ "vmware" ];

  environment.variables = {

  };

}
