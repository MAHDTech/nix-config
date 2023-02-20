{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: vscode.nix
# Description: VSCode extension management
##################################################

let

  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

in {

  home.packages = [

    #pkgs.vscode
    #pkgs.vscode-with-extensions

  ];

  programs = {

    vscode = {

      enable = true ;

      package = pkgsUnstable.vscode ;

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
