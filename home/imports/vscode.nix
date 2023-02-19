{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: vscode.nix
# Description: VSCode extension management
##################################################

{

  home.packages = [

    #pkgs.vscode
    #pkgs.vscode-with-extensions

  ];

  programs = {

    vscode = {

      enable = true ;

      package = pkgs.vscode ;
      #package = inputs.nixpkgs-unstable.packages.${pkgs.system}.vscode ;

      extensions = with pkgs.vscode-extensions ; [

        # Currently managing extensions via settings sync.

      ];

    };

  };

  home.sessionVariables = {

    # Enable wayland support in electron apps.
    NIXOS_OZONE_WL = "1";

  };

}
