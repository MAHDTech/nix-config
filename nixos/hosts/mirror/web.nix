# cspell:ignore namedirfirst nosniff
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mirror;
  collections = [
    "nutanix/lcm/release"
    "nutanix/nkp"
    "nutanix/bundles"
    "nutanix/images"
    "nutanix/ova"
    "f5/packages"
    "f5/images"
    "f5/ova"
    "terraform"
    "iso"
    "images"
    "ubuntu"
    "redhat"
  ];
  landing = pkgs.writeTextDir "index.html" (
    builtins.replaceStrings
      [ "@hostname@" "@version@" "@system@" "@hub@" ]
      [
        (lib.escapeXML config.networking.hostName)
        (lib.escapeXML config.system.nixos.release)
        (lib.escapeXML pkgs.stdenv.hostPlatform.system)
        (lib.escapeXML (import ../fleet.nix).beszel.url)
      ]
      (builtins.readFile ./landing.html)
  );
  fileServer = ''
    root * /srv/mirror
    file_server {
      index __no_index_files__
      browse ${./browse.html} {
        sort namedirfirst
      }
    }
  '';
in
{
  options.services.mirror.allowedNetworks = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "127.0.0.1/32"
      "::1/128"
    ];
    description = "Client CIDRs allowed to browse and download mirror content.";
  };
  config = {
    systemd = {
      tmpfiles.rules = [
        "d /srv/mirror 0755 root root -"
      ]
      ++ map (path: "d /srv/mirror/${path} 0755 root root -") collections;
      services = {
        mirror-summary = {
          description = "Collect mirror disk statistics";
          serviceConfig = {
            Type = "oneshot";
            User = "caddy";
            Group = "caddy";
            StateDirectory = "mirror-summary";
            StateDirectoryMode = "0755";
            ExecStart = "${pkgs.python3}/bin/python3 ${./collect-summary.py} /srv/mirror /var/lib/mirror-summary/summary.json";
            TimeoutStartSec = "45s";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            NoNewPrivileges = true;
            CapabilityBoundingSet = "";
            Nice = 10;
            IOSchedulingClass = "idle";
            MemoryMax = "128M";
          };
          path = [ pkgs.coreutils ];
        };
      };
      timers = {
        mirror-summary = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnCalendar = "*:0/15";
            Persistent = true;
          };
        };
      };
    };
    networking.firewall.allowedTCPPorts = [ 443 ];
    services.caddy = {
      enable = true;
      enableReload = true;
      globalConfig = ''
        auto_https disable_redirects
      '';
      virtualHosts."https://mirror.slopageddon.app" = {
        useACMEHost = "mirror.slopageddon.app";
        logFormat = "output stderr";
        extraConfig = ''
          @outside not remote_ip ${lib.concatStringsSep " " cfg.allowedNetworks}
          @write not method GET HEAD
          route {
            respond @outside 403
            respond @write 405
            header X-Content-Type-Options nosniff
            handle / {
              root * ${landing}
              file_server
            }
            handle /_landing.css {
              rewrite * /landing.css
              root * ${../nix-cache}
              file_server
            }
            handle /_browse.css {
              rewrite * /browser.css
              root * ${../../system/config/services/file-browser}
              file_server
            }
            handle /_landing.js {
              rewrite * /landing.js
              root * ${./.}
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
              ${fileServer}
            }
            @collection path /nutanix /nutanix/* /f5 /f5/* /terraform /terraform/* /iso /iso/* /images /images/* /ubuntu /ubuntu/* /redhat /redhat/*
            handle @collection {
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
