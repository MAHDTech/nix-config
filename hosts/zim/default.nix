{ config, lib, nixpkgs, pkgs, ... }:

let

in {

  imports = [

    ./hardware-configuration.nix

    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    ./desktop-environment.nix

  ];

  networking = {

    hostName = "zim";
    hostId = "def00002";

  };

}
