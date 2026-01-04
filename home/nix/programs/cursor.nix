{
  inputs,
  pkgs,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  env_cursor =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      pkgs.buildEnv {
        name = "cursor-env";
        paths = [
          "${pkgsUnstable.code-cursor-fhs}/bin"
          "${pkgs.golangci-lint}/bin"
          "${pkgs.go}/bin"
        ];
      }
    else
      pkgs.hello;

in
{
  home.packages =
    with pkgs;
    pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
      pkgsUnstable.code-cursor-fhs
    ];

  xdg = {

    desktopEntries = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {

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
