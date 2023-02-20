{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  networking = {
    # https://developer-old.gnome.org/NetworkManager/stable/NetworkManager.conf.html
    networkmanager = {
      enable = false;

      dns = "systemd-resolved";

      plugins = with pkgs; [
        networkmanager-openvpn
        networkmanager-openconnect
      ];
    };
  };
}
