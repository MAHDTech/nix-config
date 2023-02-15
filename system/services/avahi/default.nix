{ config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  services.avahi = {

    enable = true;

    nssmdns = true;

    ipv4 = true;
    ipv6 = true;

    publish = {

      enable = true;
      address = true;
      workstation = true;

    };

  };

}