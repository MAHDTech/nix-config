{ lib, modulesPath, ... }:
{
  networking = {
    hostName = "test-nixos";
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
    "${modulesPath}/profiles/qemu-guest.nix"
    ../../system/soe
  ];
}
