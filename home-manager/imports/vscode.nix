{ config, lib, pkgs, ... }:

##################################################
# Name: vscode.nix
# Description: VSCode extension management
##################################################

{

  nixpkgs.config.allowUnfree = true ;

  home.packages = with pkgs; [

    vscode
    #vscode-with-extensions

  ];

  programs = {

    vscode = {

      enable = true ;

      package = pkgs.vscode ;

      extensions = with pkgs.vscode-extensions ; [

        # Currently managing extensions via settings sync.

      ];

    };

  };

  home.sessionVariables = {

    NIXOS_OZONE_WL = "1";

  };

}

