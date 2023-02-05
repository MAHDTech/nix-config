{ config, lib, pkgs, ... }:

##################################################
# Name: gnome-keyring.nix
# Description: Gnome Keyring configuration
##################################################

{

  home.packages = with pkgs; [

    gcr
    gnome.gnome-keyring
    gnome.seahorse

  ];

  services = {

    gnome-keyring = {

      enable = true ;

      components = [
        "pkcs11"
        "secrets"
        "ssh"
      ];

    };

  };

  xdg.configFile."autostart/gnome-keyring-ssh.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Hidden=true
  '';

}

