{ lib, ... }:
{
  boot = {
    kernelParams = [
      "console=ttyMSM0,115200n8"
      "earlycon=msm_serial,0x078B0000"
      "deferred_probe_timeout=30"
    ];

  };

  networking = {
    hostName = "BOOTYCALL";
    hostId = "def00005";
    useDHCP = lib.mkDefault true;
    firewall.checkReversePath = false;
  };

  services.oled-manager.enable = true;

  imports = [
    # Hardware Configuration
    ./hardware
    ./hardware/disko.nix

    # OS Services Configuration
    ./services
  ];
}
