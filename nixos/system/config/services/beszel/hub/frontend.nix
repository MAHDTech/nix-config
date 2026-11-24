{ config, lib, ... }:
let
  cfg = config.services.beszel.hub;
  front = cfg.frontend;
  httpsLib = import ../../internal-https/lib.nix { inherit lib; };
in
{
  imports = [ ../../internal-https ];
  options.services.beszel.hub.frontend = {
    enable = lib.mkEnableOption "Beszel HTTPS frontend with Cloudflare DNS-01";
    domain = lib.mkOption { type = lib.types.str; };
    cloudflareTokenReference = lib.mkOption { type = lib.types.str; };
    cloudflareEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    allowedNetworks = httpsLib.mkAllowedNetworksOption "Client CIDRs allowed to access the Beszel hub frontend.";
  };
  config = lib.mkIf (cfg.enable && front.enable) {
    services = {
      beszel.hub = {
        host = lib.mkDefault "127.0.0.1";
        environment.APP_URL = lib.mkDefault "https://${front.domain}";
      };
      internal-https = {
        enable = true;
        domains = [ front.domain ];
        inherit (front) cloudflareTokenReference cloudflareEmail;
      };
      nginx = {
        enable = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        virtualHosts.${front.domain} = {
          onlySSL = true;
          useACMEHost = front.domain;
          extraConfig = ''
            ${httpsLib.nginxAllowDirectives front.allowedNetworks}
            client_max_body_size 10m;
          '';
          locations."/" = {
            proxyPass = "http://${
              if lib.hasInfix ":" cfg.host then "[${cfg.host}]" else cfg.host
            }:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              ${httpsLib.nginxBaselineHeaders}
              proxy_read_timeout 360s;
              proxy_send_timeout 360s;
              proxy_buffering off;
            '';
          };
        };
      };
    };
  };
}
