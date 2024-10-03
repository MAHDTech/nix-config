{
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  # Using gnome-keyring from home-manager instead.
  services.gnome.gnome-keyring = {enable = lib.mkForce false;};
}
