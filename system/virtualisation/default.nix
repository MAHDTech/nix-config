{ config, lib, pkgs, ... }:

{

  imports = [

    ./docker
    #./flatpak                    # Enabled by default in GNOME

  ];

  environment.systemPackages = with pkgs; [

  ];

}