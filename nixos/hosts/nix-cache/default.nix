{ lib, pkgs, ... }:
let
  domain = "nix-cache.slopageddon.app";
  tokenPath = "/run/secrets/cloudflare-acme-slopageddon";
in
{
  imports = [
    ./base.nix
    ../../system/soe/nix
    ../../system/config/services/nixos-drain
    ../../system/config/services/cloudflare-acme
    ./proxy.nix
  ];

  services = {
    nixos-drain.enable = true;
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

  systemd.services = {
    nixos-upgrade = {
      preStart = "/run/current-system/sw/bin/nixos-drain drain --profile upgrade";
      postStart = "/run/current-system/sw/bin/nixos-drain cancel";
    };
    opnix-secrets = {
      wants = [ "cloud-final.service" ];
      after = [ "cloud-final.service" ];
      unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      serviceConfig = {
        RestartPreventExitStatus = lib.mkForce [ ];
        RestartSec = lib.mkForce "5min";
        TimeoutStartSec = "infinity";
      };
      preStart = ''
        while [ ! -s /etc/opnix-token ]; do
          echo "Waiting for cloud-init to deliver /etc/opnix-token"
          ${pkgs.coreutils}/bin/sleep 30
        done
      '';
    };
  };

  # Keep host upgrades independent of the cache service itself.
  system.autoUpgrade = {
    flake = lib.mkForce "github:MAHDTech/nix-config#nix-cache";
    operation = lib.mkForce "switch";
    allowReboot = lib.mkForce false;
  };
  nix.settings.trusted-users = lib.mkForce [ "root" ];
  environment.systemPackages = [
    pkgs.curl
    pkgs.jq
  ];
}
