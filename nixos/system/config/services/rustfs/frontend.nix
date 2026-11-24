{ config, lib, ... }:
let
  cfg = config.services.rustfs-managed;
  front = cfg.frontend;
  httpsLib = import ../internal-https/lib.nix { inherit lib; };
  virtualHost =
    {
      domain,
      port,
      redirectRoot ? false,
    }:
    {
      onlySSL = true;
      useACMEHost = domain;
      extraConfig = ''
        if ($rustfs_host_${toString port} = "") { return 444; }
        ${httpsLib.nginxAllowDirectives front.allowedNetworks}
        # Large multipart uploads must stream without a second disk-backed copy.
        client_max_body_size 0;
      '';
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          recommendedProxySettings = false;
          proxyWebsockets = true;
          extraConfig = ''
            ${lib.optionalString redirectRoot ''
              # Redirect unauthenticated browser visits to / while preserving
              # signed S3/STS requests (e.g. console login POST / and ListBuckets GET /).
              if ($rustfs_console_root_redirect) { return 302 /rustfs/console/; }
            ''}
            ${httpsLib.nginxBaselineHeaders}
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
    };
in
{
  imports = [
    ./default.nix
    ../internal-https
  ];
  options.services.rustfs-managed.frontend = {
    enable = lib.mkEnableOption "internal HTTPS RustFS API and console";
    apiDomain = lib.mkOption { type = lib.types.str; };
    consoleDomain = lib.mkOption { type = lib.types.str; };
    cloudflareTokenReference = lib.mkOption { type = lib.types.str; };
    cloudflareEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    allowedNetworks = httpsLib.mkAllowedNetworksOption "Networks permitted to access the API and authenticated console.";
  };
  config = lib.mkIf (cfg.enable && front.enable) {
    assertions = [
      {
        assertion = front.apiDomain != front.consoleDomain;
        message = "RustFS API and console need distinct hostnames.";
      }
    ];
    services = {
      internal-https = {
        enable = true;
        domains = [
          front.apiDomain
          front.consoleDomain
        ];
        inherit (front) cloudflareTokenReference cloudflareEmail;
      };
      nginx = {
        enable = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
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
            ]
          + ''

            map "$request_method:$uri:$http_authorization:$http_x_amz_date:$args" $rustfs_console_root_redirect {
              default 0;
              "GET:/:::" 1;
              "HEAD:/:::" 1;
            }
          '';
        virtualHosts = {
          ${front.apiDomain} = virtualHost {
            domain = front.apiDomain;
            port = cfg.apiPort;
          };
          ${front.consoleDomain} = virtualHost {
            domain = front.consoleDomain;
            port = cfg.consolePort;
            redirectRoot = true;
          };
        };
      };
    };
  };
}
