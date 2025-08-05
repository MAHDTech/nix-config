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

        portSecure = mkOption {
          type = types.int;
          default = 3371;
          description = "Port for LINSTOR controller REST API (secure)";
        };

        bind = mkOption {
          type = types.str;
          default = "0.0.0.0";
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
            description = "Database connection URL (required if not using embedded H2)";
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
          default = "0.0.0.0";
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

      # Create users and groups
      users = {

        groups = {
          lvm = { }; # Ensure LVM group exists
          disk = { }; # Ensure disk group exists
          ${cfg.group} = { }; # Ensure linstor group exists
        };

        users = {
          ${cfg.user} = {
            isSystemUser = true;
            inherit (cfg) group;
            description = "LINSTOR service user";
            home = cfg.dataDir;
            createHome = true;
            extraGroups = [
              "disk"
              "lvm"
            ]; # Add storage-related groups
          };
        };
      };

      # Allow linstor user to perform storage operations
      security.sudo.extraRules = [
        {
          users = [ cfg.user ];
          commands = [
            # Storage discovery and management
            {
              command = "${pkgs.util-linux}/bin/lsblk";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.lvm2}/bin/lvm";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.util-linux}/bin/blkid";
              options = [ "NOPASSWD" ];
            }
            # DRBD operations
            {
              command = "${pkgs.drbd}/bin/drbdadm";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.drbd}/bin/drbdsetup";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.drbd}/bin/drbdmeta";
              options = [ "NOPASSWD" ];
            }
            # ZFS operations
            {
              command = "${pkgs.zfs}/bin/zfs";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.zfs}/bin/zpool";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      # Create data directory
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/controller 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/satellite 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/storage-pools 0755 ${cfg.user} ${cfg.group} -"
      ];
    })

    #########################################################
    # Controller configuration
    #########################################################

    (mkIf cfg.controller.enable {

      systemd.services.linstor-controller = {
        description = "LINSTOR Controller";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "var-lib-linstor.mount"
          "var-lib-linstor-storage\\x2dpools.mount"
        ];
        requires = [
          "network.target"
          "var-lib-linstor.mount"
        ];

        environment = {
          LS_KEEP_RES = "1";
        };

        serviceConfig = {
          Type = "notify";
          User = cfg.user;
          Group = cfg.group;
          ExecStartPre = pkgs.writeShellScript "linstor-controller-setup" ''
            ${pkgs.coreutils}/bin/echo "Setting up controller directory"
            ${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/controller
            ${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} ${cfg.dataDir}/controller
            ${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} ${cfg.dataDir}

            if [ -d "${cfg.dataDir}/storage-pools" ];
            then
              ${pkgs.coreutils}/bin/echo "Setting up storage-pools directory"
              ${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}/storage-pools
            fi
          '';
          ExecStart = "${cfg.package}/bin/linstor-controller --config-directory=${cfg.dataDir}/controller --rest-bind=${cfg.controller.bind}:${toString cfg.controller.port} --rest-bind-secure=${cfg.controller.bind}:${toString cfg.controller.portSecure}";
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
      };

      # Open firewall port for controller
      networking.firewall.allowedTCPPorts = [
        cfg.controller.port
        cfg.controller.portSecure
      ];
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
          "var-lib-linstor.mount"
        ];
        requires = [
          "network.target"
          "var-lib-linstor.mount"
        ];

        environment = {
          # Ensure satellite has access to all storage tools
          PATH = lib.mkOverride 500 (
            lib.mkDefault "${
              lib.makeBinPath [
                pkgs.drbd # drbdadm, drbdsetup, drbdmeta
                pkgs.lvm2 # lvm, pvcreate, vgcreate, lvcreate, etc.
                pkgs.zfs # zfs, zpool
                pkgs.util-linux # lsblk, blkid, mount, umount
                pkgs.coreutils # basic utilities
                pkgs.gnused # sed
                pkgs.gnugrep # grep
                pkgs.gawk # awk
                pkgs.findutils # find
                pkgs.procps # ps, pgrep
                pkgs.kmod # modprobe
              ]
            }:/run/current-system/sw/bin"
          );
        };

        serviceConfig = {
          Type = "notify";
          User = cfg.user;
          Group = cfg.group;
          ExecStartPre = pkgs.writeShellScript "linstor-satellite-setup" ''
            ${pkgs.coreutils}/bin/echo "Setting up satellite directory"
            ${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/satellite
            ${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} ${cfg.dataDir}/satellite
            ${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} ${cfg.dataDir}

            if [ -d "${cfg.dataDir}/storage-pools" ];
            then
              ${pkgs.coreutils}/bin/echo "Setting up storage-pools directory"
              ${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}/storage-pools
            fi
          '';
          ExecStart = "${cfg.package}/bin/linstor-satellite --config-directory=${cfg.dataDir}/satellite --bind-address=${cfg.satellite.bind} --port=${toString cfg.satellite.port}";
          WorkingDirectory = "${cfg.dataDir}/satellite";
          Restart = "on-failure";
          RestartSec = "30s";

          # Security settings
          NoNewPrivileges = false;
          PrivateTmp = true;
        };
      };

      # Open firewall port for satellite
      networking.firewall.allowedTCPPorts = [
        cfg.satellite.port
      ];

    })
  ];
}
