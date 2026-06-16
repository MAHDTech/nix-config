{ lib, ... }:
{
  networking = {
    hostName = "BOOTYCALL";
    hostId = "def00005";
    useDHCP = lib.mkDefault true;
  };

  imports = [
    # Hardware Configuration
    ./hardware-configuration.nix

    # OS Services Configuration
    ./services
  ];
}
