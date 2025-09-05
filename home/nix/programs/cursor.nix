{
  config,
  inputs,
  pkgs,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

  env_cursor = pkgs.buildEnv {
    name = "cursor-env";
    paths = [
      "${pkgsUnstable.code-cursor-fhs}/bin"
      "${pkgs.golangci-lint}/bin"
      "${pkgs.go}/bin"
    ];
  };

in
{
  home.packages = with pkgs; [
    #code-cursor-fhs
    pkgsUnstable.code-cursor-fhs
  ];

  xdg = {

    desktopEntries = {

      cursor = {
        name = "Cursor";
        genericName = "AI-first coding environment";
        comment = "Cursor is an AI-first coding environment.";
        exec = "${env_cursor}/cursor --no-sandbox %U";
        icon = "cursor";
        settings = {
          Keywords = "editor;cursor";
        };
        categories = [
          "Utility"
          "TextEditor"
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "application/x-zerosize"
          "x-scheme-handler/cursor"
        ];
      };

    };

  };

}
