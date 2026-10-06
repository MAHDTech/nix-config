{ lib, pkgs, ... }:
{
  imports = [
    ../../system/virtualisation/qemu-guest.nix
    ../../system/soe/nix
    ../../system/config/services/cloudflare-acme
    ./web.nix
  ];
  networking.hostName = "mirror";
  services = {
    cloud-init.settings.preserve_hostname = true;
    journald.settings.Journal.SystemMaxUse = "1G";
    cloudflare-acme = {
      enable = true;
      domains = [ "mirror.slopageddon.app" ];
      tokenReference = "op://fleet/Cloudflare ACME Slopageddon/token";
      certificateGroup = "caddy";
      reloadServices = [ "caddy.service" ];
    };
  };
  system.autoUpgrade.flake = lib.mkForce "github:MAHDTech/nix-config#mirror";
  nix.settings.trusted-users = lib.mkForce [ "root" ];
  environment.systemPackages = [ pkgs.rsync ];
}
