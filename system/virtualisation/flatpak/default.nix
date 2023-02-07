{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  # XDG Desktop Portal is needed for flatpaks to work.
  xdg.portal = {

    enable = true;

    wlr.enable = true;

    extraPortals = with pkgs; [

      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr

    ];

  };

}