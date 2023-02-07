{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  powerManagement = {

    enable = true;

    powertop = {

        enable = true;

    };

    cpuFreqGovernor = "performance";

    resumeCommands = ''
      echo "Resuming from suspend..."
    '';

  };

}