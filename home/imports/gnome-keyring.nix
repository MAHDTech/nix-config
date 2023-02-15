{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: gnome-keyring.nix
# Description: Gnome Keyring configuration
##################################################

{

  home.packages = with pkgs; [

    gcr
    gnome.gnome-keyring
    gnome.seahorse
    libsecret

  ];

  services = {

    gnome-keyring = {

      enable = false ;

      components = [
        "pkcs11"
        "secrets"
        "ssh"
      ];

    };

  };

}
