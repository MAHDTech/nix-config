{ config, lib, ... }:
let
  cfg = config.services.rustfs-managed;
  front = cfg.frontend;
  virtualHost = domain: port: {
    forceSSL = true;
    useACMEHost = domain;
    extraConfig = ''
      if ($rustfs_host_${toString port} = "") { return 444; }
      ${lib.concatMapStringsSep "\n" (network: "allow ${network};") front.allowedNetworks}
      deny all;
      # Large multipart uploads must stream without a second disk-backed copy.
      client_max_body_size 0;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      recommendedProxySettings = false;
      proxyWebsockets = true;
      extraConfig = ''
        # Preserve the signed Host, URI and query string for S3 Signature V4.
        proxy_set_header Host $rustfs_host_${toString port};
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_request_buffering off;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_redirect off;
      '';
    };
  };
in
{
  imports = [
    ./default.nix
    ../cloudflare-acme
  ];
  options.services.rustfs-managed.frontend = {
    enable = lib.mkEnableOption "internal HTTPS RustFS API and console";
    apiDomain = lib.mkOption { type = lib.types.str; };
    consoleDomain = lib.mkOption { type = lib.types.str; };
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
      description = "Networks permitted to access the API and authenticated console.";
    };
  };
  config = lib.mkIf (cfg.enable && front.enable) {
    assertions = [
      {
        assertion = front.apiDomain != front.consoleDomain;
        message = "RustFS API and console need distinct hostnames.";
      }
    ];
    services.cloudflare-acme = {
      enable = true;
      domains = [
        front.apiDomain
        front.consoleDomain
      ];
      tokenReference = front.cloudflareTokenReference;
    };
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      # Keep the exact signed authority (including an explicit :443), but only
      # forward the two configured hostnames, never an arbitrary Host header.
      commonHttpConfig =
        lib.concatMapStringsSep "\n"
          (entry: ''
            map $http_host $rustfs_host_${toString entry.port} {
              default "";
              "${entry.domain}" "${entry.domain}";
              "${entry.domain}:443" "${entry.domain}:443";
            }
          '')
          [
            {
              domain = front.apiDomain;
              port = cfg.apiPort;
            }
            {
              domain = front.consoleDomain;
              port = cfg.consolePort;
            }
          ];
      virtualHosts = {
        ${front.apiDomain} = virtualHost front.apiDomain cfg.apiPort;
        ${front.consoleDomain} = virtualHost front.consoleDomain cfg.consolePort;
      };
    };
    networking.firewall.allowedTCPPorts = [ 443 ];
  };
}
