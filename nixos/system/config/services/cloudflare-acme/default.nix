{ config, lib, ... }:
let
  cfg = config.services.cloudflare-acme;
  renewals = map (domain: "acme-order-renew-${domain}.service") cfg.domains;
in
{
  imports = [ ../../../soe/secrets/opnix.nix ];
  options.services.cloudflare-acme = {
    enable = lib.mkEnableOption "Cloudflare DNS-01 certificates with Opnix credentials";
    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    tokenReference = lib.mkOption { type = lib.types.str; };
    retryIntervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "Delay between failed certificate requests. Retries continue until success; 15 minutes accommodates ACME authorization-failure limits.";
    };
    tokenPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/cloudflare-acme-token";
    };
  };
  config = lib.mkIf cfg.enable {
    services.onepassword-secrets.secrets.cloudflareAcme = {
      reference = cfg.tokenReference;
      path = cfg.tokenPath;
      owner = "root";
      group = "root";
      mode = "0400";
      services = renewals;
    };
    security.acme = {
      acceptTerms = true;
      certs = lib.genAttrs cfg.domains (_: {
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        credentialFiles.CF_DNS_API_TOKEN_FILE = cfg.tokenPath;
        group = "nginx";
        reloadServices = [ "nginx.service" ];
      });
    };
    systemd.services = lib.genAttrs (map (domain: "acme-order-renew-${domain}") cfg.domains) (_: {
      requires = [ "opnix-secrets.service" ];
      after = [ "opnix-secrets.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = lib.mkForce cfg.retryIntervalSeconds;
      };
    });
  };
}
