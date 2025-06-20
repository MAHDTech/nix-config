{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  _unstablePkgs = with pkgsUnstable; [ ];

in
# Visual Studio Code Insiders
#vscode-insiders = (pkgs.vscode.override {isInsiders = true;}).overrideAttrs (_oldAttrs: {
#  version = "latest";
#  src = builtins.fetchTarball {
#    #url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
#    url = "file:///nix/store/bxnc6b84x19h0l3q1l19alql0vi6b6yf-code-insider-x64-1685339015.tar.gz";
#    sha256 = "sha256:0ykj7jwh5gbx6r695b27258yci3xf001vd28h6w7w5h7d3aaqnhz";
#  };
#});
{
  home.packages = [
  ];
  #++ unstablePkgs;

  programs = {
    vscode = {
      enable = true;

      package = pkgs.vscode.fhs;

      mutableExtensionsDir = true;

      profiles.default = {
        enableExtensionUpdateCheck = true;
        enableUpdateCheck = true;

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
  };
}
