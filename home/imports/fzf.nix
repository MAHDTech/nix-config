{ config, lib, pkgs, ... }:

##################################################
# Name: fzf.nix
# Description: Fuzzy Finder config
##################################################

{

  programs.fzf = {

    enable = true;

    enableBashIntegration = true;

  };

}

