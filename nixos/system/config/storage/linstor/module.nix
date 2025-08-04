{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.linstor;
  linstor-server = pkgs.callPackage ./package.nix { };
in
{
  #########################################################
  # Interface
  #########################################################

  options = {

    services.linstor = {

      #########################################################
      # Controller options
      #########################################################

      controller = {
        enable = mkEnableOption "LINSTOR controller service";

        port = mkOption {
          type = types.int;
          default = 3370;
          description = "Port for LINSTOR controller REST API";
        };

        bind = mkOption {
          type = types.str;
          default = "::0";
          description = "IP address to bind the controller to";
        };

        database = {
          type = mkOption {
            type = types.enum [
              "h2"
              "postgresql"
              "mariadb"
              "etcd"
            ];
            default = "h2";
            description = "Database backend type";
          };

          connectionUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Database connection URL (if not using embedded H2)";
          };

          user = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Database username";
          };

          passwordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "File containing database password";
          };
        };
      };

      #########################################################
      # Satellite options
      #########################################################

      satellite = {
        enable = mkEnableOption "LINSTOR satellite service";

        controllerEndpoint = mkOption {
          type = types.str;
          default = "linstor://localhost:3370";
          description = "LINSTOR controller endpoint for satellite to connect to";
        };

        port = mkOption {
          type = types.int;
          default = 3366;
          description = "Port for LINSTOR satellite communication";
        };

        bind = mkOption {
          type = types.str;
          default = "::0";
          description = "IP address to bind the satellite to";
        };
      };

      #########################################################
      # Common options
      #########################################################

      package = mkOption {
        type = types.package;
        default = linstor-server;
        description = "LINSTOR package to use";
      };

      user = mkOption {
        type = types.str;
        default = "linstor";
        description = "User to run LINSTOR services as";
      };

      group = mkOption {
        type = types.str;
        default = "linstor";
        description = "Group to run LINSTOR services as";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/linstor";
        description = "Data directory for LINSTOR";
      };
    };
  };

  #########################################################
  # Implementation
  #########################################################

  config = mkMerge [

    #########################################################
    # Common configuration
    #########################################################

    (mkIf (cfg.controller.enable || cfg.satellite.enable) {

      # Ensure DRBD kernel module is loaded
      boot.kernelModules = [ "drbd" ];

      # Required system packages
      environment.systemPackages = with pkgs; [
        cfg.package
        drbd
        lvm2
      ];

      # Create user and group
      users.groups.${cfg.group} = { };
      users.users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        description = "LINSTOR service user";
        home = cfg.dataDir;
        createHome = true;
      };

      # Create data directory
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/controller 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/satellite 0755 ${cfg.user} ${cfg.group} -"
      ];
    })

    #########################################################
    # Controller configuration
    #########################################################

    (mkIf cfg.controller.enable {

      systemd.services.linstor-controller = {
        description = "LINSTOR Controller";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        requires = [ "network.target" ];

        environment = {
          LS_KEEP_RES = "1";
        };

        serviceConfig = {
          Type = "notify";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${cfg.package}/bin/linstor-controller";
          WorkingDirectory = "${cfg.dataDir}/controller";
          Restart = "on-failure";
          RestartSec = "10s";

          # Security settings
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.dataDir ];
        };

        preStart = ''
          # Ensure proper ownership
          chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
        '';
      };

      # Open firewall port for controller
      networking.firewall.allowedTCPPorts = [ cfg.controller.port ];
    })

    #########################################################
    # Satellite configuration
    #########################################################

    (mkIf cfg.satellite.enable {

      systemd.services.linstor-satellite = {
        description = "LINSTOR Satellite";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "lvm2-monitor.service"
        ];
        requires = [ "network.target" ];

        serviceConfig = {
          Type = "notify";
          User = "root"; # Satellite needs root for storage operations
          ExecStart = "${cfg.package}/bin/linstor-satellite";
          WorkingDirectory = "${cfg.dataDir}/satellite";
          Restart = "on-failure";
          RestartSec = "10s";

          # Less restrictive security for storage operations
          NoNewPrivileges = false;
          PrivateTmp = true;
        };

        preStart = ''
          # Ensure proper ownership
          chown -R root:root ${cfg.dataDir}/satellite
        '';
      };

      # Open firewall port for satellite
      networking.firewall.allowedTCPPorts = [ cfg.satellite.port ];
    })
  ];
}
