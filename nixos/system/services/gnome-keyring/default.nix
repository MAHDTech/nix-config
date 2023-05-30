{
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.gnome.gnome-keyring = {enable = lib.mkForce false;};
}
