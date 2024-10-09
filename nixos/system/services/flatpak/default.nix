{pkgs, ...}: {
  #########################
  # NOTES:
  #
  #   This needs the declarative-flatpak support module.
  #
  #########################

  imports = [];

  environment.systemPackages = with pkgs; [
    xdg-utils
    xdg-launch
  ];

  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  services.flatpak = {
    enable = true;

    # <remote name>:<type>/<flatpak ref>/<arch>/<branch>:<commit>
    packages = [
      "flathub:app/com.discordapp.Discord//stable"
      "flathub:app/com.github.PintaProject.Pinta//stable"
      "flathub:app/com.github.tchx84.Flatseal//stable"
      "flathub:app/com.google.Chrome//stable"
      "flathub:app/com.logseq.Logseq//stable"
      "flathub:app/com.obsproject.Studio//stable"
      "flathub:app/com.slack.Slack//stable"
      "flathub:app/com.valvesoftware.Steam//stable"
      "flathub:app/net.codeindustry.MasterPDFEditor//stable"
      "flathub:app/org.ferdium.Ferdium//stable"
      "flathub:app/org.gimp.GIMP//stable"
      "flathub:app/org.signal.Signal//stable"
      "flathub:app/org.videolan.VLC//stable"
    ];

    remotes = {
      "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
    };
  };

  # If you're not using GNOME, XDG Desktop Portal is needed for flatpaks to work.
  xdg.portal = {
    enable = true;

    xdgOpenUsePortal = true;

    wlr.enable = true;

    config = {
      common = {
        default = [
          "gtk"
        ];
      };
      cosmic = {
        default = [
          "cosmic"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
      pantheon = {
        default = [
          "pantheon"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };

    extraPortals = with pkgs; [
      pantheon.xdg-desktop-portal-pantheon
      xdg-desktop-portal-cosmic
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
  };
}
