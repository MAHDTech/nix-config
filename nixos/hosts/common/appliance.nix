{ lib, name, ... }:
{
  imports = [
    ../../system/virtualisation/qemu-guest.nix
    ../../system/soe/nix
  ];

  networking.hostName = lib.mkDefault name;
  services = {
    cloud-init.settings.preserve_hostname = true;
    journald.settings.Journal.SystemMaxUse = "1G";
  };
  system.autoUpgrade.flake = lib.mkForce "github:MAHDTech/nix-config#${name}";
  nix.settings.trusted-users = lib.mkForce [ "root" ];
}
