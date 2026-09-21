{ config, lib, ... }:
let
  cfg = config.services.nix-cache-proxy;
  upstreams = builtins.fromJSON (
    builtins.readFile ../../system/config/services/nix-cache/upstreams.json
  );
  proxySettings = host: ''
    proxy_set_header Host ${host};
    proxy_ssl_server_name on;
    proxy_ssl_name ${host};
    proxy_ssl_verify on;
    # Allow upstream certificate chains with multiple intermediate certificates.
    proxy_ssl_verify_depth 3;
    proxy_ssl_trusted_certificate ${config.security.pki.caBundle};
    proxy_connect_timeout 5s;
    proxy_read_timeout 60s;
    proxy_cache nixpkgs;
    proxy_cache_key "${host}$request_uri";
    proxy_no_cache $nix_cache_skip;
    proxy_cache_lock on;
    proxy_cache_lock_timeout 120s;
    proxy_cache_lock_age 120s;
    proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
    proxy_cache_revalidate on;
    add_header X-Cache-Status $upstream_cache_status always;
    limit_except GET { deny all; }
  '';
  cacheLocations =
    cache:
    let
      location = pattern: ttl: extra: {
        name = "~ \"^${cache.prefix}(${pattern})$\"";
        value = {
          proxyPass = "https://$nix_cache_upstream$1$is_args$args";
          recommendedProxySettings = false;
          extraConfig = ''
            set $nix_cache_upstream ${cache.host};
            ${proxySettings cache.host}
            proxy_cache_valid 200 ${ttl};
            ${extra}
          '';
        };
      };
    in
    [
      (location "/nix-cache-info" "1h" "")
      (location "/[0-9a-z]{32}\\.narinfo" "1h" "proxy_ignore_headers Cache-Control Expires;")
      (location "/nar/.*" "365d" "")
    ];

in
{
  options.services.nix-cache-proxy.allowedNetworks = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "127.0.0.1/32"
      "::1/128"
    ];
    description = "Client CIDRs allowed to read the cache; narrow to routed environment networks as needed.";
  };

  config = {
    networking.firewall.allowedTCPPorts = [ 443 ];
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      resolver = {
        addresses = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        valid = "300s";
        ipv6 = false;
      };
      commonHttpConfig = ''
        # The NixOS proxyCachePath options do not expose min_free.
        proxy_cache_path /var/cache/nginx/nixpkgs levels=1:2 keys_zone=nixpkgs:128m
          max_size=750g min_free=100g inactive=30d use_temp_path=off;
        map $upstream_status $nix_cache_skip {
          default 1;
          200 0;
        }
        log_format nix_cache '$remote_addr "$request" $status $body_bytes_sent '
                              '$upstream_cache_status $request_time';
      '';
      virtualHosts."nix-cache.slopageddon.app" = {
        extraConfig = ''
          access_log /var/log/nginx/nix-cache-access.log nix_cache;
          ${lib.concatMapStringsSep "\n" (network: "allow ${network};") cfg.allowedNetworks}
          deny all;
        '';
        locations = builtins.listToAttrs (lib.concatMap cacheLocations upstreams) // {
          "/".return = "404";
        };
      };
    };
  };
}
