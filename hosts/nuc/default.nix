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

    ./desktop-environment.nix

  ];

  networking = {

    hostName = "nuc";
    hostId = "def00001";

  };

}
