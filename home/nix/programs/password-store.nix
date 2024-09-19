{
  config,
  pkgs,
  ...
}: let
  storePath = "${config.home.homeDirectory}/.local/share/password-store";
in {
  home.packages = with pkgs; [tessen];

  programs = {
    password-store = {
      enable = false;

      package = pkgs.pass-wayland.withExtensions (
        exts:
          with exts; [
            pass-otp
            pass-import
            pass-audit
          ]
      );

      settings = {
        PASSWORD_STORE_DIR = storePath;
        PASSWORD_STORE_CLIP_TIME = "60";
      };
    };
  };
}
