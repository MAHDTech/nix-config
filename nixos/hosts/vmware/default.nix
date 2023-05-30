{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    # System defaults
    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    ./desktop-gnome.nix

    # Virtualization
    ../../system/virtualisation/guest
  ];

  networking = {
    hostName = "vmware";
    hostId = "def10001";
  };
}
