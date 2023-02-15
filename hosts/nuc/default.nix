{ inputs, config, lib, pkgs, ... }:

{

  imports = [

    ./hardware-configuration.nix

    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    #./desktop-pantheon.nix
    ./desktop-gnome.nix

    # Laptop
    ./battery

  ];

  networking = {

    hostName = "nuc";
    hostId = "def00001";

  };

}
