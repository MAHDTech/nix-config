{ lib, pkgs, ... }:
let
  domain = "nix-cache.slopageddon.app";
  tokenPath = "/run/secrets/cloudflare-acme-slopageddon";
in
{
  imports = [
    ./base.nix
    ../../system/soe/nix
    ../../system/config/services/cloudflare-acme
    ./proxy.nix
    ./drain.nix
  ];

  services = {
    cloudflare-acme = {
      enable = true;
      domains = [ domain ];
      tokenReference = "op://fleet/Cloudflare ACME Slopageddon/token";
      inherit tokenPath;
    };
    nginx.virtualHosts.${domain} = {
      forceSSL = true;
      useACMEHost = domain;
    };
  };

  # Keep host upgrades independent of the cache service itself.
  system.autoUpgrade = {
    flake = lib.mkForce "github:MAHDTech/nix-config#nix-cache";
  };
  nix.settings.trusted-users = lib.mkForce [ "root" ];
  environment.systemPackages = [
    pkgs.curl
    pkgs.jq
  ];
}
