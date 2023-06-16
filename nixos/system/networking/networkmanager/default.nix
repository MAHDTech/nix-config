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
      enable = true;

      #dns = "systemd-resolved";
      dns = "default";

      dhcp = "internal";

      plugins = with pkgs; [
        networkmanager-openvpn
        networkmanager-openconnect
      ];

      wifi = {
        backend = "iwd";
      };
    };
  };
}
