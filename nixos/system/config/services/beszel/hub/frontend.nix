{ config, lib, ... }:
let
  cfg = config.services.beszel.hub;
  front = cfg.frontend;
in
{
  imports = [ ../../cloudflare-acme ];
  options.services.beszel.hub.frontend = {
    enable = lib.mkEnableOption "Beszel HTTPS frontend with Cloudflare DNS-01";
    domain = lib.mkOption { type = lib.types.str; };
    cloudflareTokenReference = lib.mkOption { type = lib.types.str; };
    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "127.0.0.1/32"
        "::1/128"
      ];
    };
  };
  config = lib.mkIf (cfg.enable && front.enable) {
    networking.firewall.allowedTCPPorts = [ 443 ];
    services = {
      beszel.hub = {
        host = lib.mkDefault "127.0.0.1";
        environment.APP_URL = lib.mkDefault "https://${front.domain}";
      };
      cloudflare-acme = {
        enable = true;
        domains = [ front.domain ];
        tokenReference = front.cloudflareTokenReference;
      };
      nginx = {
        enable = true;
        recommendedTlsSettings = true;
        virtualHosts.${front.domain} = {
          forceSSL = true;
          useACMEHost = front.domain;
          extraConfig = ''
            ${lib.concatMapStringsSep "\n" (network: "allow ${network};") front.allowedNetworks}
            deny all;
            client_max_body_size 10m;
          '';
          locations."/" = {
            proxyPass = "http://${
              if lib.hasInfix ":" cfg.host then "[${cfg.host}]" else cfg.host
            }:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
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
