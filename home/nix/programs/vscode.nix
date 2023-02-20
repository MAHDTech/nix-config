{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages =
    [
      #pkgs.vscode
      #pkgs.vscode-with-extensions
    ]
    ++ unstablePkgs;

  programs = {
    vscode = {
      enable = true;

      package = pkgsUnstable.vscode;

      extensions = with pkgs.vscode-extensions; [
        # Currently managing extensions via VSCode settings sync.
      ];
    };
  };
}
