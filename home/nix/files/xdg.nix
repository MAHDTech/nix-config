{
  config,
  pkgs,
  ...
}:
let

  env_cursor = pkgs.buildEnv {
    name = "cursor-env";
    paths = [
      "${pkgs.go}/bin"
      "${pkgs.golangci-lint}/bin"
    ];
  };

in
{
  home.packages = with pkgs; [
    xdg-user-dirs
    xdg-utils
  ];
  xdg = {
    enable = true;

    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";

    systemDirs = {
      # Directory names to add to XDG_CONFIG_DIRS
      config = [ ];

      # Directory names to add to XDG_DATA_DIRS
      data = [
        "/var/lib/flatpak/exports/share"
        "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
      ];
    };

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

    dataFile = {
      "1password.desktop" = {
        target = "applications/1password.desktop";

        text = ''
          [Desktop Entry]
          Name=1Password
          Exec=${pkgs._1password-gui}/bin/1password %U
          Terminal=false
          Type=Application
          Icon=${pkgs._1password-gui}/share/icons/hicolor/256x256/apps/1password.png
          StartupWMClass=1Password
          Comment=Password manager and secure wallet
          MimeType=x-scheme-handler/onepassword;
          Categories=Office;
        '';
      };

      "cursor.desktop" = {
        target = "applications/cursor.desktop";

        text = ''
          [Desktop Entry]
          Name=Cursor
          Exec=${env_cursor}/bin/cursor --no-sandbox %U
          Path=${config.home.homeDirectory}/dotfiles
          Terminal=false
          Type=Application
          Icon=${pkgs.code-cursor}/share/icons/hicolor/256x256/apps/cursor.png
          StartupWMClass=Cursor
          Comment=Cursor is an AI-first coding environment.
          MimeType=x-scheme-handler/cursor;
          Categories=Utility;
        '';
      };

      "google-chrome.desktop" = {
        target = "applications/google-chrome.desktop";

        text = ''
          [Desktop Entry]
          Name=Google Chrome
          Exec=${pkgs.google-chrome}/bin/google-chrome-stable %U
          Terminal=false
          Type=Application
          Icon=${pkgs.google-chrome}/share/icons/hicolor/256x256/apps/google-chrome.png
          StartupWMClass=google-chrome
          Comment=Web Browser
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
          Categories=Network;WebBrowser;
        '';
      };

      "signal.desktop" = {
        target = "applications/signal.desktop";

        text = ''
          [Desktop Entry]
          Name=Signal
          Exec=${pkgs.signal-desktop}/bin/signal-desktop --no-sandbox %U
          Terminal=false
          Type=Application
          Icon=${pkgs.signal-desktop}/share/icons/hicolor/256x256/apps/signal-desktop.png
          StartupWMClass=signal
          Comment=Private messaging from your desktop
          MimeType=x-scheme-handler/sgnl;x-scheme-handler/signalcaptcha;
          Categories=Network;InstantMessaging;Chat;
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
        XDG_WALLPAPERS_DIR = "${config.home.homeDirectory}/Pictures/Wallpapers";
        XDG_WORKSPACES_DIR = "${config.home.homeDirectory}/Workspaces";
      };
    };
  };
}
