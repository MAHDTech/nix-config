# cspell:ignore nosniff
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nix-cache-proxy;
  cacheLimitGiB = 750;
  cacheReserveGiB = 100;
  upstreams = builtins.fromJSON (
    builtins.readFile ../../system/config/services/nix-cache/upstreams.json
  );
  landingPage = pkgs.writeText "nix-cache-index.html" (
    builtins.replaceStrings
      [ "@hostname@" "@system@" "@version@" "@hub@" "@upstreams@" ]
      [
        (lib.escapeXML config.networking.hostName)
        (lib.escapeXML pkgs.stdenv.hostPlatform.system)
        (lib.escapeXML config.system.nixos.release)
        (lib.escapeXML (import ../fleet.nix).beszel.url)
        (lib.concatMapStringsSep "\n" (upstream: ''
          <li data-endpoint="${lib.escapeXML upstream.name}"><div><span>${lib.escapeXML upstream.name}</span><span class="origin">${lib.escapeXML upstream.host}</span></div><div class="endpoint-summary"><span class="endpoint-status">Not checked</span><span class="endpoint-metrics">—</span></div></li>
        '') upstreams)
      ]
      (builtins.readFile ./landing.html)
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
    systemd = {
      services = {
        nix-cache-summary = {
          description = "Collect cache health, capacity and traffic statistics";
          after = [
            "network-online.target"
            "nginx.service"
          ];
          wants = [ "network-online.target" ];
          path = [
            pkgs.curl
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            # Nginx cache directories are private to its service user (0700).
            User = config.services.nginx.user;
            Group = config.services.nginx.group;
            StateDirectory = "nix-cache-summary";
            StateDirectoryMode = "0755";
            ExecStart = "${pkgs.python3}/bin/python3 ${./collect-summary.py} ${../../system/config/services/nix-cache/upstreams.json} /var/lib/nix-cache-summary/summary.json --limit-gib ${toString cacheLimitGiB} --reserve-gib ${toString cacheReserveGiB}";
            TimeoutStartSec = "2min";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            CapabilityBoundingSet = "";
            Nice = 10;
            IOSchedulingClass = "idle";
            MemoryMax = "128M";
          };
        };
        nix-cache-catalog = {
          description = "Index cached Nix downloads for the file browser";
          after = [ "nginx.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = config.services.nginx.user;
            Group = config.services.nginx.group;
            StateDirectory = "nix-cache-catalog";
            StateDirectoryMode = "0755";
            ExecStart = "${pkgs.python3}/bin/python3 ${./collect-catalog.py} ${../../system/config/services/nix-cache/upstreams.json} /var/lib/nix-cache-catalog/catalog.json";
            TimeoutStartSec = "2min";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            NoNewPrivileges = true;
            CapabilityBoundingSet = "";
            Nice = 10;
            IOSchedulingClass = "idle";
            MemoryMax = "256M";
          };
        };
      };
      timers = {
        nix-cache-summary = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnCalendar = "*:0/15";
            Persistent = true;
          };
        };
        nix-cache-catalog = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnCalendar = "*:0/15";
            Persistent = true;
          };
        };
      };
    };
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
          max_size=${toString cacheLimitGiB}g min_free=${toString cacheReserveGiB}g inactive=30d use_temp_path=off;
        map $upstream_status $nix_cache_skip {
          default 1;
          200 0;
        }
        log_format nix_cache escape=json '{"time":"$time_iso8601","method":"$request_method",'
          '"uri":"$uri","status":$status,"bytes":$body_bytes_sent,'
          '"cache":"$upstream_cache_status","duration":$request_time}';
      '';
      virtualHosts."nix-cache.slopageddon.app" = {
        extraConfig = ''
          access_log /var/log/nginx/nix-cache-access.log nix_cache;
          ${lib.concatMapStringsSep "\n" (network: "allow ${network};") cfg.allowedNetworks}
          deny all;
        '';
        locations = builtins.listToAttrs (lib.concatMap cacheLocations upstreams) // {
          "= /browse".return = "308 /browse/";
          "= /browse/" = {
            root = pkgs.linkFarm "nix-cache-catalog-page" [
              {
                name = "index.html";
                path = ./catalog.html;
              }
            ];
            tryFiles = "/index.html =404";
            extraConfig = ''
              default_type text/html;
              access_log off;
              limit_except GET { deny all; }
              add_header Cache-Control "no-cache";
            '';
          };
          "= /_catalog.js" = {
            alias = "${./catalog.js}";
            extraConfig = ''
              types { }
              default_type application/javascript;
              access_log off;
              limit_except GET { deny all; }
            '';
          };
          "= /_browse.css" = {
            alias = "${../../system/config/services/file-browser/browser.css}";
            extraConfig = ''
              default_type text/css;
              access_log off;
              limit_except GET { deny all; }
            '';
          };
          "= /_dashboard/catalog.json" = {
            alias = "/var/lib/nix-cache-catalog/catalog.json";
            extraConfig = ''
              default_type application/json;
              access_log off;
              limit_except GET { deny all; }
              add_header Cache-Control "no-store" always;
              add_header X-Content-Type-Options "nosniff" always;
            '';
          };
          "= /_dashboard/summary.json" = {
            alias = "/var/lib/nix-cache-summary/summary.json";
            extraConfig = ''
              default_type application/json;
              access_log off;
              limit_except GET { deny all; }
              add_header Cache-Control "no-store" always;
              add_header X-Content-Type-Options "nosniff" always;
            '';
          };
          "= /_landing.js" = {
            alias = "${./landing.js}";
            extraConfig = ''
              types { }
              default_type application/javascript;
              access_log off;
              limit_except GET { deny all; }
              add_header X-Content-Type-Options "nosniff" always;
            '';
          };
          "= /_landing.css" = {
            alias = "${./landing.css}";
            extraConfig = ''
              default_type text/css;
              access_log off;
              limit_except GET { deny all; }
              add_header X-Content-Type-Options "nosniff" always;
            '';
          };
          "= /" = {
            root = pkgs.linkFarm "nix-cache-landing" [
              {
                name = "index.html";
                path = landingPage;
              }
            ];
            tryFiles = "/index.html =404";
            extraConfig = ''
              default_type text/html;
              access_log off;
              limit_except GET { deny all; }
              add_header X-Content-Type-Options "nosniff" always;
              add_header Cache-Control "no-cache";
            '';
          };
          "/".return = "404";
        };
      };
    };
  };
}
