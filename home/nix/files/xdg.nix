{
  config,
  pkgs,
  lib,
  osConfig ? null,
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
    }
    // (
      let
        hostname =
          if
            osConfig != null
            && builtins.hasAttr "networking" osConfig
            && builtins.hasAttr "hostName" osConfig.networking
          then
            osConfig.networking.hostName
          else
            "";
      in
      if lib.hasInfix "ORION" hostname then
        {
          "uwsm/env" = {
            target = "uwsm/env";
            text = ''
              export AQ_DRM_DEVICES="/dev/dri/cix-gpu:/dev/dri/cix-display"
              export AQ_NO_MODIFIERS=1
            '';
          };
        }
      else
        { }
    );

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
      setSessionVariables = true;

      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      publicShare = "${config.home.homeDirectory}/Public";
      templates = "${config.home.homeDirectory}/Templates";
      videos = "${config.home.homeDirectory}/Videos";

      extraConfig = {
        PROJECTS = "${config.home.homeDirectory}/Projects";
        SOFTWARE = "${config.home.homeDirectory}/Software";
        WALLPAPERS = "${config.home.homeDirectory}/Pictures/Wallpapers";
        WORKSPACES = "${config.home.homeDirectory}/Workspaces";
      };
    };
  };
}
