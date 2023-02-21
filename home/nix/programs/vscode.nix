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

      enableExtensionUpdateCheck = true;
      enableUpdateCheck = true;

      mutableExtensionsDir = true;

      extensions = with pkgs.vscode-extensions; [
        # TODO: Currently managing extensions via VSCode settings sync.
      ];

      userSettings = {
        # TODO: Currently managing settings via VSCode settings sync.
      };

      # Careful, these override the vim extension.
      keybindings = [
        {
          key = "ctrl+shift+e";
          command = "workbench.action.files.openFileFolder";
          when = "editorTextFocus";
        }
      ];
    };
  };
}
