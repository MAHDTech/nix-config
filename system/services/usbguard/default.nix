{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  services.usbguard = {

    enable = false;

  };

}