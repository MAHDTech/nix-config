{ config, lib, ... }:
let
  cfg = config.services.cloudflare-acme;
  renewals = map (domain: "acme-order-renew-${domain}") cfg.domains;
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
    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Contact email registered with Let's Encrypt for expiry and revocation notices.";
    };
    retryIntervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "Delay between failed certificate requests. Retries continue until success; 15 minutes accommodates ACME authorization-failure limits.";
    };
    tokenPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/cloudflare-acme-token";
    };
    certificateGroup = lib.mkOption {
      type = lib.types.str;
      default = "nginx";
      description = "Group allowed to read the issued certificates.";
    };
    reloadServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nginx.service" ];
      description = "Services to reload after certificate renewal.";
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
      certs = lib.genAttrs cfg.domains (
        _:
        {
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          credentialFiles.CF_DNS_API_TOKEN_FILE = cfg.tokenPath;
          group = cfg.certificateGroup;
          inherit (cfg) reloadServices;
        }
        // lib.optionalAttrs (cfg.email != null) { inherit (cfg) email; }
      );
    };
    systemd.services = lib.genAttrs renewals (_: {
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
