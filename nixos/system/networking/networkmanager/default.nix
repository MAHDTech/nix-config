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

      # "none", "default", "dnsmasq", "unbound", "systemd-resolved"
      dns = "systemd-resolved";

      dhcp = "internal";

      plugins = with pkgs; [
        networkmanager-openvpn
        networkmanager-openconnect
      ];

      wifi = {
        backend = "iwd";
      };

      # systemd-network for wired
      unmanaged = [
        "enp61s0"
        "enp7s0u1u4u4"
        "Wired Connection 1"
        "Wired Connection 2"
      ];
    };
  };
}
