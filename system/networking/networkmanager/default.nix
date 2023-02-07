{ config, lib, nixpkgs, pkgs, ... }:

{

  networking = {

    # https://developer-old.gnome.org/NetworkManager/stable/NetworkManager.conf.html
    networkmanager = {

      enable = true;

      dns = "systemd-resolved";

      plugins = with pkgs; [

        networkmanager-openvpn
        networkmanager-openconnect

      ];

    };

  };

}