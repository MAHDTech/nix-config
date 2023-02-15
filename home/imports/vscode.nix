{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: vscode.nix
# Description: VSCode extension management
##################################################

let

  #pkgsUnstable = inputs.nixpkgs-unstable.packages;

in {

  home.packages = [

    #pkgs.vscode
    #pkgs.vscode-with-extensions

    #pkgsUnstable.vscode

  ];

  programs = {

    vscode = {

      enable = true ;

      package = pkgs.vscode ;
      #package = nixpkgs-unstable.packages.${pkgs.system}.vscode ;

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
