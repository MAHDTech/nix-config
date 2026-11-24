{ config, lib, ... }:
let
  cfg = config.services.internal-https;
  helpers = import ./lib.nix { inherit lib; };
in
{
  imports = [ ../cloudflare-acme ];

  options.services.internal-https = {
    enable = lib.mkEnableOption "shared internal HTTPS defaults (Cloudflare ACME, firewall, catch-all)";
    allowedNetworks = helpers.mkAllowedNetworksOption "Client CIDRs allowed to reach internal HTTPS services.";
    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    cloudflareTokenReference = lib.mkOption {
      type = lib.types.str;
    };
    cloudflareEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    certificateGroup = lib.mkOption {
      type = lib.types.str;
      default = "nginx";
    };
    reloadServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nginx.service" ];
    };
    enableNginxCatchAll = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Reject unknown Host/SNI requests on Nginx with a default catch-all virtual host.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 443 ];
    services = {
      cloudflare-acme = {
        enable = true;
        inherit (cfg) domains certificateGroup reloadServices;
        tokenReference = cfg.cloudflareTokenReference;
        email = cfg.cloudflareEmail;
      };
      nginx = lib.mkIf (config.services.nginx.enable && cfg.enableNginxCatchAll) {
        virtualHosts."_" = helpers.nginxRejectDefaultVirtualHost;
      };
    };
  };
}
