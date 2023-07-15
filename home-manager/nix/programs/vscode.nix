{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];

  # Visual Studio Code Insiders
  vscode-insiders = (pkgs.vscode.override {isInsiders = true;}).overrideAttrs (_oldAttrs: {
    version = "latest";
    src = builtins.fetchTarball {
      #url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
      url = "file:///nix/store/bxnc6b84x19h0l3q1l19alql0vi6b6yf-code-insider-x64-1685339015.tar.gz";
      sha256 = "sha256:0ykj7jwh5gbx6r695b27258yci3xf001vd28h6w7w5h7d3aaqnhz";
    };
  });
in {
  home.packages =
    [
      #vscode-insiders
    ]
    ++ unstablePkgs;

  programs = {
    vscode = {
      enable = false;

      package = pkgsUnstable.vscode-fhs;

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
