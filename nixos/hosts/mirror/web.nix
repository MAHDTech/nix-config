# cspell:ignore namedirfirst nosniff
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mirror;
  fleet = import ../fleet.nix;
  httpsLib = import ../../system/config/services/internal-https/lib.nix { inherit lib; };
  web = import ../../system/config/services/slopageddon-web { inherit lib pkgs; };
  mkCollector = import ../../system/config/services/collector/mk-collector.nix;

  collections = [
    {
      root = "nutanix";
      label = "Nutanix";
      description = "LCM, NKP, bundles and appliances";
      subdirectories = [
        "lcm/release"
        "nkp"
        "bundles"
        "images"
        "ova"
      ];
    }
    {
      root = "f5";
      label = "F5";
      description = "Packages, disk images and appliances";
      subdirectories = [
        "packages"
        "images"
        "ova"
      ];
    }
    {
      root = "terraform";
      label = "OpenTofu / Terraform";
      description = "Provider mirror";
      subdirectories = [ ];
    }
    {
      root = "iso";
      label = "Installation media";
      description = "ISO files";
      subdirectories = [ ];
    }
    {
      root = "images";
      label = "Disk images";
      description = "Generic VM images";
      subdirectories = [ "ova" ];
    }
    {
      root = "ubuntu";
      label = "Ubuntu";
      description = "DEB packages";
      subdirectories = [ ];
    }
    {
      root = "redhat";
      label = "Red Hat";
      description = "RPM packages";
      subdirectories = [ ];
    }
  ];

  collectionDirs = lib.concatMap (
    entry: [ entry.root ] ++ map (sub: "${entry.root}/${sub}") entry.subdirectories
  ) collections;

  collectionPaths = lib.concatMapStringsSep " " (
    entry: "/${entry.root} /${entry.root}/*"
  ) collections;

  collectionsHtml = lib.concatMapStringsSep "\n" (entry: ''
    <li>
      <a href="/${lib.escapeXML entry.root}/">${lib.escapeXML entry.label} <span>${lib.escapeXML entry.description} <span aria-hidden="true">→</span></span></a>
    </li>
  '') collections;

  landing = pkgs.writeTextDir "index.html" (
    web.mkPage {
      title = "Mirror // Slopageddon";
      activeNav = "mirror";
      headerLinkHref = "/browse/";
      headerLinkLabel = "Browse files";
      includeBrowserCss = true;
      extraScripts = [ "/_landing.js" ];
      heroHtml = ''
        <h1 id="title">One mirror.<br /><span>Many sources.</span></h1>
        <p class="intro">Software, images and dark-site bundles for the Slopageddon fleet.</p>
      '';
      hubUrl = fleet.beszel.url;
      bodyHtml = builtins.replaceStrings [ "@collections@" ] [ collectionsHtml ] (
        builtins.readFile ./landing.html
      );
      systemSummary = {
        hostname = config.networking.hostName;
        version = config.system.nixos.release;
        system = pkgs.stdenv.hostPlatform.system;
      };
    }
  );

  browseTemplate = pkgs.writeText "mirror-browse.html" (
    web.mkPage {
      title = "{{html .Name}} // Slopageddon Mirror";
      activeNav = "mirror";
      brandIsLink = true;
      headerLinkHref = "/";
      headerLinkLabel = "Back to home";
      headerLinkBack = true;
      includeBrowserCss = true;
      includeCommonJs = false;
      compactHero = true;
      heroHtml = ''
        <h1 id="title">Mirror files.<br /><span>Direct downloads.</span></h1>
        <p class="intro">Static packages, images and bundles served from this host.</p>
      '';
      bodyHtml = builtins.readFile ./browse.html;
    }
  );

  mirrorAssets = pkgs.linkFarm "mirror-web-assets" [
    {
      name = "landing.js";
      path = ./landing.js;
    }
  ];

  summaryCollector = mkCollector {
    description = "Collect mirror disk statistics";
    user = "caddy";
    group = "caddy";
    stateDirectory = "mirror-summary";
    execStart = "${pkgs.python3}/bin/python3 ${./collect-summary.py} /srv/mirror /var/lib/mirror-summary/summary.json";
    path = [ pkgs.coreutils ];
    timeoutStartSec = "45s";
    memoryMax = "128M";
    onBootSec = "1min";
    onCalendar = "*:0/15";
    needsNetwork = false;
  };

  fileServer = ''
    root * /srv/mirror
    file_server {
      index __no_index_files__
      browse ${browseTemplate} {
        sort namedirfirst
      }
    }
  '';
in
{
  options.services.mirror.allowedNetworks = httpsLib.mkAllowedNetworksOption "Client CIDRs allowed to browse and download mirror content.";

  config = {
    systemd = {
      tmpfiles.rules = [
        "d /srv/mirror 0755 root root -"
      ]
      ++ map (path: "d /srv/mirror/${path} 0755 root root -") collectionDirs;
      services.mirror-summary = summaryCollector.service;
      timers.mirror-summary = summaryCollector.timer;
    };

    services.caddy = {
      enable = true;
      enableReload = true;
      globalConfig = ''
        auto_https disable_redirects
      '';
      virtualHosts."https://mirror.${fleet.domain}" = {
        useACMEHost = "mirror.${fleet.domain}";
        logFormat = "output stderr";
        extraConfig = ''
          @outside not remote_ip ${lib.concatStringsSep " " cfg.allowedNetworks}
          @write not method GET HEAD
          route {
            respond @outside 403
            respond @write 405
            header {
              X-Content-Type-Options nosniff
              Referrer-Policy no-referrer
            }
            redir /favicon.ico /_favicon.svg 308
            handle / {
              root * ${landing}
              header Cache-Control no-cache
              header X-Frame-Options DENY
              header Content-Security-Policy "${web.cspHeader}"
              file_server
            }
            handle /_favicon.svg {
              rewrite * /favicon.svg
              root * ${web.assets}
              header Cache-Control no-cache
              file_server
            }
            handle /_landing.css {
              rewrite * /landing.css
              root * ${web.assets}
              header Cache-Control no-cache
              file_server
            }
            handle /_browse.css {
              rewrite * /browser.css
              root * ${web.assets}
              header Cache-Control no-cache
              file_server
            }
            handle /_common.js {
              rewrite * /common.js
              root * ${web.assets}
              header Cache-Control no-cache
              file_server
            }
            handle /_landing.js {
              rewrite * /landing.js
              root * ${mirrorAssets}
              header Cache-Control no-cache
              file_server
            }
            handle /_dashboard/summary.json {
              rewrite * /summary.json
              root * /var/lib/mirror-summary
              header Cache-Control no-store
              file_server
            }
            redir /browse /browse/ 308
            handle /browse/ {
              rewrite * /
              header Cache-Control no-cache
              header X-Frame-Options DENY
              header Content-Security-Policy "${web.cspHeader}"
              ${fileServer}
            }
            @collection path ${collectionPaths}
            handle @collection {
              header X-Frame-Options DENY
              header Content-Security-Policy "${web.cspHeader}"
              ${fileServer}
            }
            handle {
              respond 404
            }
          }
        '';
      };
    };
  };
}
