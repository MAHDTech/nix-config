{ lib, pkgs, ... }:
let
  domain = "nix-cache.slopageddon.app";
  tokenPath = "/run/secrets/cloudflare-acme-slopageddon";
  renewalService = "acme-order-renew-${domain}";
in
{
  imports = [
    ./base.nix
    ../../system/soe/nix
    ../../system/config/services/nixos-drain
    ../../system/soe/secrets/opnix.nix
    ./proxy.nix
  ];

  services = {
    nixos-drain.enable = true;
    onepassword-secrets.secrets.cloudflareAcmeSlopageddon = {
      reference = "op://fleet/Cloudflare ACME Slopageddon/token";
      path = tokenPath;
      owner = "root";
      group = "root";
      mode = "0400";
      services = [ renewalService ];
    };
    nginx.virtualHosts.${domain} = {
      forceSSL = true;
      useACMEHost = domain;
    };
  };

  security.acme = {
    acceptTerms = true;
    certs.${domain} = {
      dnsProvider = "cloudflare";
      # Public validation must bypass any internal split DNS zone.
      dnsResolver = "1.1.1.1:53";
      credentialFiles.CF_DNS_API_TOKEN_FILE = tokenPath;
      group = "nginx";
      reloadServices = [ "nginx.service" ];
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
    ${renewalService} = {
      requires = [ "opnix-secrets.service" ];
      after = [ "opnix-secrets.service" ];
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
