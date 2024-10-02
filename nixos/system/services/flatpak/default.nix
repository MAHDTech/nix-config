{pkgs, ...}: {
  #########################
  # NOTES:
  #
  #   This needs the declarative-flatpak support module.
  #
  #########################

  imports = [];

  environment.systemPackages = with pkgs; [];

  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  services.flatpak = {
    enable = true;

    flatpak-dir = "/var/lib/flatpak";

    # <remote name>:<type>/<flatpak ref>/<arch>/<branch>:<commit>
    packages = [
      "flathub:app/com.google.Chrome//stable"
      "flathub:app/com.github.tchx84.Flatseal//stable"
    ];

    remotes = {
      "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
    };
  };

  # If you're not using GNOME, XDG Desktop Portal is needed for flatpaks to work.
  xdg.portal = {
    enable = true;

    wlr.enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
      xdg-desktop-portal-cosmic
      pantheon.xdg-desktop-portal-pantheon
    ];
  };
}
