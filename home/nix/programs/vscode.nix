{
  inputs,
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
      #pkgs.vscode.fhs
    ]
    ++ unstablePkgs;

  programs = {
    vscode = {
      enable = true;

      package = pkgsUnstable.vscode.fhs;

      enableExtensionUpdateCheck = true;
      enableUpdateCheck = true;

      mutableExtensionsDir = true;

      extensions = with pkgs.vscode-extensions; [
      ];

      userSettings = {
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
