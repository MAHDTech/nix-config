{pkgs, ...}: {
  #########################
  # NOTES:
  #
  #   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #   flatpak update
  #   flatpak search $NAME
  #   flatpak install flathub $NAME
  #
  #########################

  imports = [];

  environment.systemPackages = with pkgs; [];

  services.flatpak = {enable = false;};

  # If you're not using GNOME, XDG Desktop Portal is needed for flatpaks to work.
  #xdg.portal = {
  #  enable = true;
  #
  #  wlr.enable = true;
  #
  #  extraPortals = with pkgs; [xdg-desktop-portal-gtk xdg-desktop-portal-wlr];
  #};
}
