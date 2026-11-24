# cspell:ignore nosniff
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nix-cache-proxy;
  fleet = import ../fleet.nix;
  httpsLib = import ../../system/config/services/internal-https/lib.nix { inherit lib; };
  web = import ../../system/config/services/slopageddon-web { inherit lib pkgs; };
  mkCollector = import ../../system/config/services/collector/mk-collector.nix;

  cacheLimitGiB = 750;
  cacheReserveGiB = 100;
  upstreams = builtins.fromJSON (
    builtins.readFile ../../system/config/services/nix-cache/upstreams.json
  );
  upstreamsHtml = lib.concatMapStringsSep "\n" (upstream: ''
    <li data-endpoint="${lib.escapeXML upstream.name}">
      <div>
        <span>${lib.escapeXML upstream.name}</span>
        <span class="origin">${lib.escapeXML upstream.host}</span>
      </div>
      <div class="endpoint-summary">
        <span class="endpoint-status">Not checked</span>
        <span class="endpoint-metrics">—</span>
      </div>
    </li>
  '') upstreams;

  landingPage = pkgs.writeText "nix-cache-index.html" (
    web.mkPage {
      title = "Nix Cache // Slopageddon";
      activeNav = "nix-cache";
      headerLinkHref = "/browse/";
      headerLinkLabel = "Browse files";
      extraScripts = [ "/_landing.js" ];
      heroHtml = ''
        <h1 id="title">Build less.<br /><span>Ship more.</span></h1>
        <p class="intro">Shared Nix packages for the Slopageddon fleet.</p>
      '';
      hubUrl = fleet.beszel.url;
      bodyHtml = builtins.replaceStrings [ "@upstreams@" ] [ upstreamsHtml ] (
        builtins.readFile ./landing.html
      );
      systemSummary = {
        hostname = config.networking.hostName;
        version = config.system.nixos.release;
        system = pkgs.stdenv.hostPlatform.system;
      };
    }
  );

  catalogPage = pkgs.writeText "nix-cache-catalog.html" (
    web.mkPage {
      title = "Browse Nix Cache // Slopageddon";
      activeNav = "nix-cache";
      brandIsLink = true;
      headerLinkHref = "/";
      headerLinkLabel = "Back to home";
      headerLinkBack = true;
      includeBrowserCss = true;
      extraScripts = [ "/_catalog.js" ];
      compactHero = true;
      heroHtml = ''
        <h1 id="title">Already here.<br /><span>Ready to build.</span></h1>
        <p class="intro">Cached Nix packages and archives on this host.</p>
      '';
      bodyHtml = builtins.readFile ./catalog.html;
    }
  );

  staticAsset =
    {
      path,
      mimeType,
      noTypes ? false,
      cacheControl ? "no-cache",
    }:
    {
      alias = "${path}";
      extraConfig = ''
        ${lib.optionalString noTypes "types { }"}
        default_type ${mimeType};
        access_log off;
        limit_except GET { deny all; }
        add_header Cache-Control "${cacheControl}" always;
        ${httpsLib.nginxBaselineHeaders}
      '';
    };

  htmlLocation = name: file: {
    root = pkgs.linkFarm name [
      {
        name = "index.html";
        path = file;
      }
    ];
    tryFiles = "/index.html =404";
    extraConfig = ''
      default_type text/html;
      access_log off;
      limit_except GET { deny all; }
      add_header Cache-Control "no-cache" always;
      ${httpsLib.nginxHtmlHeaders web.cspHeader}
    '';
  };

  summaryCollector = mkCollector {
    description = "Collect cache health, capacity and traffic statistics";
    user = config.services.nginx.user;
    group = config.services.nginx.group;
    stateDirectory = "nix-cache-summary";
    after = [
      "network-online.target"
      "nginx.service"
    ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.curl
      pkgs.coreutils
    ];
    execStart = "${pkgs.python3}/bin/python3 ${./collect-summary.py} ${../../system/config/services/nix-cache/upstreams.json} /var/lib/nix-cache-summary/summary.json --limit-gib ${toString cacheLimitGiB} --reserve-gib ${toString cacheReserveGiB}";
    timeoutStartSec = "2min";
    memoryMax = "128M";
    onBootSec = "1min";
    onCalendar = "*:0/15";
    needsNetwork = true;
  };

  catalogCollector = mkCollector {
    description = "Index cached Nix downloads for the file browser";
    user = config.services.nginx.user;
    group = config.services.nginx.group;
    stateDirectory = "nix-cache-catalog";
    after = [ "nginx.service" ];
    execStart = "${pkgs.python3}/bin/python3 ${./collect-catalog.py} ${../../system/config/services/nix-cache/upstreams.json} /var/lib/nix-cache-catalog/catalog.json";
    timeoutStartSec = "2min";
    memoryMax = "256M";
    onBootSec = "2min";
    # Stagger away from nix-cache-summary (*:0/15) to avoid concurrent cache-tree scans.
    onCalendar = "*:07/15";
    needsNetwork = false;
  };

  proxySettings = host: skipVar: ''
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
    proxy_no_cache ${skipVar};
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
            ${proxySettings cache.host "$nix_cache_skip"}
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
  options.services.nix-cache-proxy.allowedNetworks = httpsLib.mkAllowedNetworksOption "Client CIDRs allowed to read the cache; narrow to routed environment networks as needed.";

  config = {
    systemd = {
      services = {
        nix-cache-summary = summaryCollector.service;
        nix-cache-catalog = catalogCollector.service;
      };
      timers = {
        nix-cache-summary = summaryCollector.timer;
        nix-cache-catalog = catalogCollector.timer;
      };
    };

    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
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
        map $upstream_status $nix_tarballs_skip {
          default 1;
          200 0;
          301 0;
        }
        log_format nix_cache escape=json '{"time":"$time_iso8601","method":"$request_method",'
          '"uri":"$uri","status":$status,"bytes":$body_bytes_sent,'
          '"cache":"$upstream_cache_status","duration":$request_time}';
      '';
      virtualHosts."nix-cache.${fleet.domain}" = {
        extraConfig = ''
          access_log /var/log/nginx/nix-cache-access.log nix_cache;
          ${httpsLib.nginxAllowDirectives cfg.allowedNetworks}
        '';
        locations = builtins.listToAttrs (lib.concatMap cacheLocations upstreams) // {
          # Content-addressed hashed mirror for builtins.fetchurl / pkgs.fetchurl.
          # tarballs.nixos.org redirects /sha256/<h> to /sha512/<h> via HTTP 301.
          "~ \"^/tarballs(/(?:md5|sha1|sha256|sha512)/[0-9a-zA-Z]{32,128})$\"" = {
            proxyPass = "https://$nix_cache_upstream$1$is_args$args";
            recommendedProxySettings = false;
            extraConfig = ''
              set $nix_cache_upstream tarballs.nixos.org;
              ${proxySettings "tarballs.nixos.org" "$nix_tarballs_skip"}
              proxy_cache_valid 200 301 365d;
              proxy_redirect https://tarballs.nixos.org/ /tarballs/;
              proxy_redirect / /tarballs/;
            '';
          };
          "= /favicon.ico" = {
            return = "308 /_favicon.svg";
            extraConfig = ''
              access_log off;
            '';
          };
          "= /_favicon.svg" = staticAsset {
            path = "${web.assets}/favicon.svg";
            mimeType = "image/svg+xml";
          };
          "= /browse" = {
            return = "308 /browse/";
            extraConfig = "access_log off;";
          };
          "= /browse/" = htmlLocation "nix-cache-catalog-page" catalogPage;
          "= /_common.js" = staticAsset {
            path = "${web.assets}/common.js";
            mimeType = "application/javascript";
            noTypes = true;
          };
          "= /_catalog.js" = staticAsset {
            path = ./catalog.js;
            mimeType = "application/javascript";
            noTypes = true;
          };
          "= /_browse.css" = staticAsset {
            path = "${web.assets}/browser.css";
            mimeType = "text/css";
          };
          "= /_dashboard/catalog.json" = staticAsset {
            path = "/var/lib/nix-cache-catalog/catalog.json";
            mimeType = "application/json";
            cacheControl = "no-store";
          };
          "= /_dashboard/summary.json" = staticAsset {
            path = "/var/lib/nix-cache-summary/summary.json";
            mimeType = "application/json";
            cacheControl = "no-store";
          };
          "= /_landing.js" = staticAsset {
            path = ./landing.js;
            mimeType = "application/javascript";
            noTypes = true;
          };
          "= /_landing.css" = staticAsset {
            path = "${web.assets}/landing.css";
            mimeType = "text/css";
          };
          "= /" = htmlLocation "nix-cache-landing" landingPage;
          "/".return = "404";
        };
      };
    };
  };
}
