{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  services.zfs = {

    autoScrub = {

      enable = true;

      interval = "weekly";

      pools = [];

    };

    trim = {

      enable = true;

      interval = "weekly";

    };

  };

}