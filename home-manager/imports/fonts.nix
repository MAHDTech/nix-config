{ config, lib, pkgs, ... }:

##################################################
# Name: fonts.nix
# Description: Fonts
##################################################

{

  home.packages = with pkgs; [

    cascadia-code
    corefonts
    jetbrains-mono
    nerdfonts
    ubuntu_font_family
    dejavu_fonts
    redhat-official-fonts

  ];

  fonts.fontconfig = {

    enable = true ;

  };

}

