{ inputs, config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  virtualisation = {

    vmware = {

      guest = {

        enable = true;

        headless = false;

      };

    };

  };

}