{
  inputs,
  config,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs; [xdg-user-dirs xdg-utils] ++ unstablePkgs;

  xdg = {
    enable = true;
    configFile = {
      # Enable hardware acceleration for VP9 on Intel GPUs
      "mpv.conf" = {
        target = "mpv/mpv.conf";

        text = ''
          hwdec=auto-safe
          vo=gpu
          profile=gpu-hq
          gpu-context=wayland
        '';
      };
    };

    # Set default user directories to home directory
    userDirs = {
      enable = true;

      createDirectories = true;

      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      publicShare = "${config.home.homeDirectory}/Public";
      templates = "${config.home.homeDirectory}/Templates";
      videos = "${config.home.homeDirectory}/Videos";

      extraConfig = {
        XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
        XDG_SOFTWARE_DIR = "${config.home.homeDirectory}/Software";
      };
    };
  };
}
