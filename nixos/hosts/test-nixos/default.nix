{ lib, ... }:
{
  networking = {
    hostName = "test-nixos";
    hostId = "def00006";
    useDHCP = lib.mkDefault true;
  };

  services = {
    cloud-init = {
      enable = true;
      network.enable = true;
    };
    qemuGuest.enable = true;
  };

  imports = [
    ./hardware
    ../../system/soe
  ];
}
