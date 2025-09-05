{
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    xdg-user-dirs
    xdg-utils

    # GTK themes
    adw-gtk3
  ];
  xdg = {
    enable = true;

    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";

    systemDirs = {
      # Directory names to add to XDG_CONFIG_DIRS
      config = [
        "/etc/xdg"
      ];

      # Directory names to add to XDG_DATA_DIRS
      data = [
        "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
        "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/share/applications"
        "/usr/local/share"
        "/usr/local/share/applications"
        "/usr/share"
        "/usr/share/applications"
        "/var/lib/flatpak/exports/share"
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

      # Enable Cosmic theme for GTK applications
      "gtk-3.0/settings.ini" = {
        target = "gtk-3.0/settings.ini";

        text = ''
          [Settings]
          gtk-theme-name=adw-gtk3
        '';
      };
    };

    dataFile = {
      "1password.desktop" = {
        target = "applications/1password.desktop";

        text = ''
          [Desktop Entry]
          Name=1Password
          Exec=env GDK_BACKEND=x11 ELECTRON_OZONE_PLATFORM_HINT=x11 ${pkgs._1password-gui}/bin/1password %U
          Terminal=false
          Type=Application
          Icon=${pkgs._1password-gui}/share/icons/hicolor/256x256/apps/1password.png
          StartupWMClass=1Password
          Comment=Password manager and secure wallet
          MimeType=x-scheme-handler/onepassword;
          Categories=Office;
        '';
      };

      #"google-chrome.desktop" = {
      #  target = "applications/google-chrome.desktop";

      #  text = ''
      #    [Desktop Entry]
      #    Name=Google Chrome
      #    Exec=${pkgs.google-chrome}/bin/google-chrome-stable %U
      #    Terminal=false
      #    Type=Application
      #    Icon=${pkgs.google-chrome}/share/icons/hicolor/256x256/apps/google-chrome.png
      #    StartupWMClass=google-chrome
      #    Comment=Web Browser
      #    MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
      #    Categories=Network;WebBrowser;
      #  '';
      #};

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
