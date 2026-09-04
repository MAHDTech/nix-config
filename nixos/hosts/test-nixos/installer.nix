{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./hardware
    ../../system/installer/base.nix
  ];

  networking = {
    hostName = "installer-test-nixos";
    hostId = "def00006";
  };

  services.openssh.enable = true;
}
