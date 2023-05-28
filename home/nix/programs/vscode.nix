{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];

  # Visual Studio Code Insiders
  vscode-insiders = (pkgs.vscode.override {isInsiders = true;}).overrideAttrs (_oldAttrs: rec {
    version = "latest";
    src = builtins.fetchTarball {
      url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
      sha256 = "sha256:1nvmnf4w2894v21zcmh1xzcxzzilc10qsqhz2i5hqvrn2vcw0ivv";
    };
  });
in {
  home.packages =
    [
      vscode-insiders
    ]
    ++ unstablePkgs;

  programs = {
    vscode = {
      enable = false;

      package = pkgsUnstable.vscode;

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
