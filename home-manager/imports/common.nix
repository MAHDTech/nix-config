{ config, lib, pkgs, ... }:

##################################################
# Name: common.nix
# Description: common nix config
##################################################

{

  programs.command-not-found = {

    enable = true ;

  };

}

