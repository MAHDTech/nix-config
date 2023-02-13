{
  config,
  lib,
  nixpkgs,
  pkgs,
  ...
}:

{

  imports = [

    ./hardware-configuration.nix

    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    #./desktop-pantheon.nix
    ./desktop-gnome.nix

  ];

  networking = {

    hostName = "nuc";
    hostId = "def00001";

  };

}
