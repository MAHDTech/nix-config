{ pkgs, ... }:
{
  #########################
  # NOTES:
  #
  #   This needs the declarative-flatpak support module.
  #
  #########################

  imports = [ ];

  environment.systemPackages = with pkgs; [
    xdg-launch
    xdg-utils
  ];

  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  services.flatpak = {
    enable = true;

    # <remote name>:<type>/<flatpak ref>/<arch>/<branch>:<commit>
    packages = [
      # Chat
      "flathub:app/com.discordapp.Discord//stable"
      #"flathub:app/com.slack.Slack//stable"
      # Flatpak
      "flathub:app/com.github.tchx84.Flatseal//stable"
      # Audio
      #"flathub:app/com.obsproject.Studio//stable"
      # Games
      "flathub:app/com.valvesoftware.Steam//stable"
      "flathub:app/com.valvesoftware.SteamLink//stable"
      "flathub:app/org.ferdium.Ferdium//stable"
      "flathub:app/org.videolan.VLC//stable"
      # Editing software
      "flathub:app/com.jgraph.drawio.desktop//stable"
      "flathub:app/com.orama_interactive.Pixelorama//stable"
      "flathub:app/net.pixieditor.PixiEditor//stable"
      "flathub:app/org.gimp.GIMP//stable"
      "flathub:app/org.kde.krita//stable"
    ];

    remotes = {
      "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
    };
  };

  # XDG portal configuration moved to hyprland.nix to avoid conflicts
  # and properly configure secret service for authentication dialogue boxes.
  # xdg.portal = {
  #   enable = true;

  #   xdgOpenUsePortal = true;

  #   wlr.enable = true;

  #   config = {
  #     common = {
  #       default = [
  #         "gtk"
  #       ];
  #     };
  #     cosmic = {
  #       default = [
  #         "cosmic"
  #         "gtk"
  #       ];
  #       "org.freedesktop.impl.portal.Secret" = [
  #         "gnome-keyring"
  #       ];
  #     };
  #     pantheon = {
  #       default = [
  #         "pantheon"
  #         "gtk"
  #       ];
  #       "org.freedesktop.impl.portal.Secret" = [
  #         "gnome-keyring"
  #       ];
  #     };
  #     hyprland = {
  #       default = [
  #         "hyprland"
  #         "gtk"
  #       ];
  #     };
  #   };

  #   extraPortals = with pkgs; [
  #     # Make sure the DE has the portal configured.
  #     #pantheon.xdg-desktop-portal-pantheon
  #     #xdg-desktop-portal-cosmic
  #     xdg-desktop-portal-gtk
  #     xdg-desktop-portal-hyprland
  #     #xdg-desktop-portal-wlr
  #   ];
  # };
}
