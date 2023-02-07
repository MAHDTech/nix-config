{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

    ./docker
    ./flatpak

  ];

  environment.systemPackages = with pkgs; [

  ];

}