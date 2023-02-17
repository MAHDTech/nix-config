{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: vim.nix
# Description: Vim and plugins configuration
##################################################

{

  programs.neovim = {

    enable = true ;

  };

}
