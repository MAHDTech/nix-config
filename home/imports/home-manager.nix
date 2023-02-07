{ config, lib, pkgs, ... }:

##################################################
# Name: home-manager.nix
# Description: Home Manager configuration.
##################################################

{

  programs.home-manager = {

    enable = true ;

  };

  home = {

    enableNixpkgsReleaseCheck = true ;

  };

}
