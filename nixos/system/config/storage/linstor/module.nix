{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.linstor;
  linstor-server = pkgs.callPackage ./packages/server.nix { };
  linstor-client = pkgs.callPackage ./packages/client.nix { };
  linstor-gui = pkgs.callPackage ./packages/gui.nix { };
in
{
  #########################################################
  # Interface
  #########################################################

  options = {

    services = {

      linstor = {

        #########################################################
        # Controller options
        #########################################################

        controller = {
          enable = mkEnableOption "LINSTOR controller service";

          logLevel = mkOption {
            type = types.str;
            default = "INFO";
            description = "Log level for LINSTOR controller";
          };

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
                "etcd"
                "h2"
                "mariadb"
                "postgresql"
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

          logLevel = mkOption {
            type = types.str;
            default = "INFO";
            description = "Log level for LINSTOR satellite";
          };

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

          zfsPool = mkOption {
            type = types.str;
            default = "zpool";
            description = "ZFS pool to use for LINSTOR storage pool";
          };
        };

        #########################################################
        # Web UI (GUI) options
        #########################################################

        # NOTE: The Web UI (GUI) needs the controller to be running to work.
        gui = {
          enable = mkEnableOption "Enable LINSTOR web UI (GUI)";

          package = mkOption {
            type = types.package;
            default = linstor-gui;
            description = "Package providing LINSTOR Web UI (GUI) assets (linstor-gui)";
          };
        };

        #########################################################
        # DRBD options
        #########################################################

        drbd = {
          enable = mkEnableOption "DRBD service for LINSTOR";

          config = mkOption {
            type = types.lines;
            default = ''
              #########################################################
              # Default DRBD configuration for LINSTOR
              #########################################################

              # Global DRBD settings
              global {

                # Disable DRBD's own logging, let systemd handle it
                usage-count no;

              }

              # Common settings for all resources
              common {

                # Protocol A for maximum performance (no replication guarantees)
                # Protocol B for synchronous replication (default)
                # Protocol C for synchronous replication with write ordering
                protocol C;

                # Startup settings
                startup {
                  wfc-timeout 0;
                  degr-wfc-timeout 120;
                  outdated-wfc-timeout 120;
                }

                # Disk settings
                disk {

                  # Enable disk flushes to ensure data hits stable storage (critical for reliability)
                  disk-flushes yes;

                  # Enable disk barriers for ordered writes (prevents corruption on failure)
                  disk-barrier yes;

                  # Enable disk drain to wait for I/O completion
                  disk-drain yes;

                  # Enable md-flushes for metadata integrity
                  md-flushes yes;

                  # Add I/O error handling: Detach on error and go diskless (safe default)
                  on-io-error detach;

                  # Prevent network saturation
                  resync-rate 512M;

                  # Define the minimum resync rate
                  c-min-rate 4096;

                }

                # Net settings
                net {

                  # Timeout settings
                  connect-int 10;
                  timeout 60;
                  ko-count 4;

                  # Buffer settings
                  sndbuf-size 0;
                  rcvbuf-size 0;

                  # Disable allow-two-primaries unless needed for dual-primary (e.g., live migration); requires fencing
                  # allow-two-primaries;  # Comment out for single-primary safety (default)

                  # Use a stronger default HMAC algorithm
                  cram-hmac-alg "sha256";

                  # Generate a unique shared secret (e.g., via `openssl rand -hex 32`); do not hardcode
                  #shared-secret "your-unique-generated-secret-here";  # Replace with a secure value (default)

                  # Split-brain policies
                  after-sb-0pri discard-zero-changes;
                  after-sb-1pri consensus;
                  after-sb-2pri disconnect;

                  # Enable replication traffic integrity checking (e.g., with SHA-256) to detect corruption
                  data-integrity-alg sha256;

                  # Enable TLS for encrypted replication (requires DRBD 9.2.6+ and keys in /etc/tlshd.conf)
                  #tls yes;

                  # Add verification algorithm for online integrity checks
                  verify-alg sha256;

                  # Add ping settings for keep-alive (explicit defaults for clarity)
                  ping-int 10;
                  ping-timeout 5;

                }
              }

              #########################################################
              # LINSTOR integration
              #########################################################

              # Include LINSTOR-generated DRBD resource definitions
              include "/var/lib/linstor.d/*.res";
            '';
            description = "DRBD configuration. This will be merged with any additional user configuration.";
          };

          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Additional DRBD configuration to merge with the default config";
          };
        };

        #########################################################
        # Common options
        #########################################################

        common = {

          serverPackage = mkOption {
            type = types.package;
            default = linstor-server;
            description = "LINSTOR server package to use";
          };

          clientPackage = mkOption {
            type = types.package;
            default = linstor-client;
            description = "LINSTOR client package to use";
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

          configDir = mkOption {
            type = types.path;
            default = "/etc/linstor";
            description = "Configuration directory for LINSTOR";
          };

          dataDir = mkOption {
            type = types.path;
            default = "/var/lib/linstor";
            description = "Data directory for LINSTOR";
          };

          metadataDir = mkOption {
            type = types.path;
            default = "/var/lib/linstor.d";
            description = "Metadata directory for LINSTOR";
          };

          logsDir = mkOption {
            type = types.path;
            default = "/var/log/linstor";
            description = "Logs directory for LINSTOR";
          };
        };
      };
    };
  };

  #########################################################
  # Implementation
  #########################################################

  config = mkMerge [

    #########################################################
    # DRBD Configuration
    #########################################################

    (mkIf cfg.drbd.enable {

      # Enable DRBD service
      services = {

        # HACK: Disable DRBD service and use our own configuration.
        # This is because the DRBD service doesn't use the out-of-tree DRBD 9 kernel module.
        # TODO: Re-look at this in future.
        drbd = {
          enable = lib.mkForce false;
          config = cfg.drbd.config + cfg.drbd.extraConfig;
        };

        udev = {
          packages = with pkgs; [
            drbd
            zfs
          ];
        };

      };

      boot = {

        # HACK: Force use of an LTS kernel to ensure we have DRBD 9 support.
        kernelPackages = lib.mkForce pkgs.linuxPackages_6_12; # LTS

        # Load DRBD 9 out-of-tree kernel module from linuxKernel.packages
        extraModulePackages = with config.boot.kernelPackages; [ drbd ];

        extraModprobeConfig = ''
          options drbd usermode_helper=/run/current-system/sw/bin/drbdadm
        '';

        # Blacklist the old DRBD in-tree kernel module
        blacklistedKernelModules = [ "drbd" ];

        # Load the DRBD 9 out-of-tree kernel module
        kernelModules = [ "drbd9" ];

      };

      environment = {

        etc = {

          # The DRBD configuration file.
          "drbd.conf" = {
            source = pkgs.writeText "drbd.conf" (cfg.drbd.config + cfg.drbd.extraConfig);
          };

        };

        # Add DRBD utilities to system packages
        systemPackages = with pkgs; [
          drbd
        ];

      };

      systemd = {

        services = {

          linstor-satellite = {
            # Ensure DRBD module is loaded before LINSTOR satellite starts
            after = [
              "systemd-modules-load.service"
            ];
          };

        };

      };
    })

    #########################################################
    # Common configuration
    #########################################################

    (mkIf (cfg.controller.enable || cfg.satellite.enable) {

      boot = {

        # Ensure LINSTOR required kernel modules are loaded.
        kernelModules = [
          # Device Mapper modules for various storage layers
          "dm-writecache"
          "dm-cache"
          "dm-thin-pool"

          # NVMe over RDMA support
          "nvmet"
          "nvmet_rdma"
          "nvme_rdma"

          # Block cache support
          "bcache"

          # LUKS encryption support
          "dm-crypt"
        ];

      };

      # Ensure LINSTOR required system packages are installed.
      environment.systemPackages = with pkgs; [
        cfg.common.serverPackage
        cfg.common.clientPackage

        # LVM tools including thin provisioning
        lvm2
        thin-provisioning-tools

        # Encryption support
        cryptsetup

        # SCSI utilities
        lsscsi

        # ZFS utilities (usually already included but ensure they're available)
        zfs

        # NVMe utilities
        nvme-cli

        # Block device utilities
        util-linux

        # File system utilities
        e2fsprogs
        xfsprogs
        btrfs-progs

        # Systemd utilities
        systemd
        sdnotify-wrapper
      ];

      # Create users and groups
      users = {

        groups = {
          lvm = { }; # Ensure LVM group exists
          disk = { }; # Ensure disk group exists
          ${cfg.common.group} = { }; # Ensure linstor group exists
        };

        users = {
          ${cfg.common.user} = {
            isSystemUser = true;
            inherit (cfg.common) group;
            description = "LINSTOR service user";
            home = cfg.common.dataDir;
            createHome = true;
            extraGroups = [
              "disk"
              "lvm"
            ];
          };
        };
      };

      # Allow linstor user to perform storage operations
      security.sudo.extraRules = [
        {
          users = [ cfg.common.user ];
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
            # Kernel module operations
            {
              command = "${pkgs.kmod}/bin/modprobe";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.kmod}/bin/rmmod";
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
            {
              command = "${pkgs.zfs}/bin/zfs list";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.zfs}/bin/zfs create";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.zfs}/bin/zfs destroy";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.zfs}/bin/zfs set";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.zfs}/bin/zfs get";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      # Create data directory
      systemd = {

        tmpfiles.rules = [
          # Create configuration directory
          "d ${cfg.common.configDir} 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d ${cfg.common.configDir}/controller 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d ${cfg.common.configDir}/satellite 0755 ${cfg.common.user} ${cfg.common.group} -"

          # Create data directory
          "d ${cfg.common.dataDir} 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d ${cfg.common.dataDir}/storage-pool 0755 ${cfg.common.user} ${cfg.common.group} -"

          # Create metadata directory
          "d ${cfg.common.metadataDir} 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d ${cfg.common.metadataDir}/.backup 0755 ${cfg.common.user} ${cfg.common.group} -"

          # Create logs directory
          "d ${cfg.common.logsDir} 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d ${cfg.common.logsDir}/controller 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d ${cfg.common.logsDir}/satellite 0755 ${cfg.common.user} ${cfg.common.group} -"

          # Ensure DRBD runtime and state directories exist for locking/metadata helpers
          "d /var/run/drbd 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d /var/run/drbd/lock 0755 ${cfg.common.user} ${cfg.common.group} -"
          "d /var/lib/drbd 0755 root root -"
        ];

        services = {
          # Configure ZFS delegation for linstor user.
          linstor-zfs-delegation = {
            description = "Configure ZFS delegation for LINSTOR";

            wantedBy = [ "multi-user.target" ];
            before = [ "linstor-satellite.service" ];
            requires = [
              "zfs-import.target"
              "zfs-mount.service"
            ];
            after = [
              "zfs-import.target"
              "zfs-mount.service"
            ];

            script = ''
              ${pkgs.coreutils}/bin/echo "Setting up ZFS delegation for ${cfg.common.user} user and ${cfg.common.group} group..."

              # Wait for the ZFS pool to be available.
              while ! ${pkgs.zfs}/bin/zfs list -r ${cfg.satellite.zfsPool} >/dev/null 2>&1;
              do
                ${pkgs.coreutils}/bin/echo "Waiting for ZFS pool ${cfg.satellite.zfsPool} to be available..."
                sleep 5
              done
              ${pkgs.coreutils}/bin/echo "ZFS pool ${cfg.satellite.zfsPool} is available, delegating permissions..."

              # TODO: /dev/zfs is already 0666, so we don't need to grant access to the group?
              # Grant access to /dev/zfs for the linstor group
              #${pkgs.coreutils}/bin/echo "Setting /dev/zfs permissions for group ${cfg.common.group}..."
              #chgrp ${cfg.common.group} /dev/zfs
              #chmod 660 /dev/zfs

              # Grant the user permissions on the storage-pool dataset.
              ${pkgs.coreutils}/bin/echo "Setting up ZFS delegation for ${cfg.common.user} user on dataset: ${cfg.satellite.zfsPool}${cfg.common.dataDir}/storage-pool"

              ${pkgs.zfs}/bin/zfs allow \
                -u ${cfg.common.user} \
                create,destroy,mount,clone,rename,rollback,snapshot,userprop,userquota,userused,refreservation,volsize,volblocksize,reservation,quota,refquota \
                ${cfg.satellite.zfsPool}${cfg.common.dataDir}/storage-pool

              # Grant the group permissions on the storage-pool dataset.
              ${pkgs.coreutils}/bin/echo "Setting up ZFS delegation for ${cfg.common.group} group on dataset: ${cfg.satellite.zfsPool}${cfg.common.dataDir}/storage-pool"

              ${pkgs.zfs}/bin/zfs allow \
                -g ${cfg.common.group} \
                create,destroy,mount,clone,rename,rollback,snapshot,userprop,userquota,userused,refreservation,volsize,volblocksize,reservation,quota,refquota \
                ${cfg.satellite.zfsPool}${cfg.common.dataDir}/storage-pool

              ${pkgs.coreutils}/bin/echo "ZFS delegation configured for ${cfg.common.user} user and group ${cfg.common.group}."
            '';

            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              RemainAfterExit = true;
            };
          };
        };
      };
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
          "zfs-import.target"
          "zfs-mount.service"
        ];
        requires = [
          "network.target"
          "var-lib-linstor.mount"
        ];

        environment = {
          LS_KEEP_RES = "1";
          PATH = lib.mkForce (
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils # basic utilities
              pkgs.sdnotify-wrapper # systemd-notify wrapper
              pkgs.systemd # systemd
            ]
          );
        };

        serviceConfig = {
          #Type = "notify"; # TODO: Fix systemd-notify.
          Type = "simple";
          TimeoutStartSec = "5m";
          User = cfg.common.user;
          Group = cfg.common.group;
          ExecStartPre = pkgs.writeShellScript "linstor-controller-pre-start" ''
            ${pkgs.coreutils}/bin/echo "Executing pre-start script for LINSTOR controller"

            # HACK: Add an artificial delay to workaround controller first-boot issues.
            ${pkgs.coreutils}/bin/sleep 30
          '';
          ExecStart = pkgs.writeShellScript "linstor-controller-start" ''
            ${pkgs.coreutils}/bin/echo "Executing start script for LINSTOR controller"

            EXTRA_FLAGS=""
            if [ "${toString cfg.gui.enable}" = "1" ] || [ "${toString cfg.gui.enable}" = "true" ];
            then
              EXTRA_FLAGS="--webui-directory=${cfg.gui.package}/share/linstor-gui"
            fi

            ${cfg.common.serverPackage}/bin/linstor-controller \
              $EXTRA_FLAGS \
              --config-directory=${cfg.common.configDir}/controller \
              --log-level-linstor=${cfg.controller.logLevel} \
              --log-level=${cfg.controller.logLevel} \
              --logs=${cfg.common.logsDir}/controller \
              --rest-bind-secure=${cfg.controller.bind}:${toString cfg.controller.portSecure} \
              --rest-bind=${cfg.controller.bind}:${toString cfg.controller.port}
          '';
          ExecStartPost = pkgs.writeShellScript "linstor-controller-post-start" ''
            ${pkgs.coreutils}/bin/echo "Executing post-start script for LINSTOR controller"
          '';
          WorkingDirectory = "${cfg.common.configDir}/controller";
          Restart = "on-failure";
          RestartSec = "30s";
          KillMode = "mixed";
          SuccessExitStatus = [
            "0"
            "143"
            "129"
          ];

          # Reduced security settings to match official service
          PrivateTmp = true;
          ReadWritePaths = [
            cfg.common.configDir
            cfg.common.dataDir
            cfg.common.logsDir
          ];
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
          "network.target"
          "var-lib-linstor.d.mount"
          "var-lib-linstor.mount"
          "zfs-import.target"
          "zfs-mount.service"
        ];
        requires = [
          "network.target"
          "var-lib-linstor.d.mount"
          "var-lib-linstor.mount"
        ];

        environment = {

          # Ensure satellite has access to all storage tools
          PATH = lib.mkForce (
            lib.makeBinPath [
              pkgs.bash # required for clone helpers invoking 'bash -c'
              pkgs.btrfs-progs # Btrfs file system utilities
              pkgs.coreutils # basic utilities (timeout, etc.)
              pkgs.cryptsetup # cryptsetup for LUKS support
              pkgs.drbd # drbdadm, drbdsetup, drbdmeta
              pkgs.e2fsprogs # file system utilities
              pkgs.findutils # find
              pkgs.gawk # awk
              pkgs.gnugrep # grep
              pkgs.gnused # sed
              pkgs.kmod # modprobe
              pkgs.lsscsi # lsscsi for SCSI device listing
              pkgs.lvm2 # lvm, pvcreate, vgcreate, lvcreate, etc.
              pkgs.nvme-cli # nvme command for NVMe support
              pkgs.procps # ps, pgrep
              pkgs.sdnotify-wrapper # systemd-notify wrapper
              pkgs.systemd # systemd
              pkgs.thin-provisioning-tools # thin_check, thin_repair
              pkgs.util-linux # lsblk, blkid, mount, umount
              pkgs.xfsprogs # XFS file system utilities
              pkgs.zfs # zfs, zpool
            ]
          );
        };

        serviceConfig = {
          #Type = "notify"; # TODO: Fix systemd-notify.
          Type = "simple";
          TimeoutStartSec = "5m";
          User = "root";
          Group = "root";
          ExecStartPre = pkgs.writeShellScript "linstor-satellite-pre-start" ''
            ${pkgs.coreutils}/bin/echo "Executing pre-start script for LINSTOR satellite"

            # Ensure the DRBD 9 kernel module is loaded before LINSTOR starts
            if ${pkgs.kmod}/bin/modprobe drbd9; then
              ${pkgs.coreutils}/bin/echo "INFO: DRBD 9 kernel module loaded successfully"
            else
              ${pkgs.coreutils}/bin/echo "WARNING: Failed to load DRBD 9 kernel module"
            fi
          '';
          ExecStart = pkgs.writeShellScript "linstor-satellite-start" ''
            ${pkgs.coreutils}/bin/echo "Executing start script for LINSTOR satellite"

            ${cfg.common.serverPackage}/bin/linstor-satellite \
              --bind-address=${cfg.satellite.bind} \
              --config-directory=${cfg.common.configDir}/satellite \
              --log-level-linstor=${cfg.satellite.logLevel} \
              --log-level=${cfg.satellite.logLevel} \
              --logs=${cfg.common.logsDir}/satellite \
              --port=${toString cfg.satellite.port}
          '';
          ExecStartPost = pkgs.writeShellScript "linstor-satellite-post-start" ''
            ${pkgs.coreutils}/bin/echo "Executing post-start script for LINSTOR satellite"
          '';
          WorkingDirectory = "${cfg.common.configDir}/satellite";
          Restart = "on-failure";
          RestartSec = "30s";
          KillMode = "mixed";
          SuccessExitStatus = [
            "0"
            "143"
            "129"
          ];

          # Security settings
          NoNewPrivileges = false; # Allow privilege escalation for kernel module loading
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          AmbientCapabilities = [
            "CAP_SYS_ADMIN"
            "CAP_SYS_MODULE"
            "CAP_MKNOD"
            "CAP_DAC_OVERRIDE"
            "CAP_FOWNER"
            "CAP_CHOWN"
            "CAP_NET_ADMIN"
            "CAP_SYS_RESOURCE"
          ];
          CapabilityBoundingSet = [
            "CAP_SYS_ADMIN"
            "CAP_SYS_MODULE"
            "CAP_MKNOD"
            "CAP_DAC_OVERRIDE"
            "CAP_FOWNER"
            "CAP_CHOWN"
            "CAP_NET_ADMIN"
            "CAP_SYS_RESOURCE"
          ];
          #DevicePolicy = "closed";
          #DeviceAllow = [
          #  "/dev/zfs rwm"
          #  "/dev/zvol/* rwm"
          #  "/dev/zd* rwm"
          #  "/dev/drbd rwm"
          #  "/dev/drbd* rwm"
          #  "/dev/mapper/* rwm"
          #  "/dev/loop-control rwm"
          #  "/dev/loop* rwm"
          #  "/dev/nvme* rwm"
          #  "/dev/sd* rwm"
          #  "block/* rwm"  # block devices
          #];
          ReadWritePaths = [
            cfg.common.configDir
            cfg.common.dataDir
            cfg.common.metadataDir
            cfg.common.logsDir
            "/var/run/drbd"
            "/var/lib/drbd"
          ];
        };
      };

      # Open firewall port for satellite
      networking.firewall.allowedTCPPorts = [
        cfg.satellite.port
      ];

    })

    #########################################################
    # Web UI (GUI) configuration
    #########################################################

    (mkIf cfg.gui.enable (mkMerge [

      {
        assertions = [
          {
            assertion = cfg.controller.enable;
            message = "services.linstor.gui.enable requires services.linstor.controller.enable = true";
          }
        ];
      }

      {
        environment.systemPackages = [ cfg.gui.package ];
      }
    ]))
  ];
}
