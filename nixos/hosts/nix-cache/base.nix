{ lib, ... }:
{
  imports = [ ../../system/virtualisation/qemu-guest.nix ];
  networking.hostName = lib.mkDefault "nix-cache";
  services.cloud-init.settings.preserve_hostname = true;
  services.journald.settings.Journal.SystemMaxUse = "1G";
}
