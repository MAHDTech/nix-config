{ inputs, config, lib, pkgs, ... }:

{

  imports = [

    ./hardware-configuration.nix

    # System defaults
    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    #./desktop-pantheon.nix
    ./desktop-gnome.nix

    # Laptop
    ./battery

    # Virtualization
    ../../system/virtualisation/host

  ];

  networking = {

    hostName = "nuc";
    hostId = "def00001";

  };

}
