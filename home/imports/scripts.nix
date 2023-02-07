{ config, lib, pkgs, ... }:

##################################################
# Name: scripts.nix
# Description: Script management with Nix.
##################################################

{

  home.file = {

    scripts = {

      recursive = true;

      source = "${config.home.homeDirectory}/.config/nixpkgs/scripts";
      target = "${config.home.homeDirectory}/.local/bin/scripts";

    };

  };

}

