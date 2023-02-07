{ config, lib, nixpkgs, pkgs, ... }:

let

in {

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  sound.enable = true;

  hardware.pulseaudio.enable = true;

  nixpkgs.config.pulseaudio = true;

  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

}