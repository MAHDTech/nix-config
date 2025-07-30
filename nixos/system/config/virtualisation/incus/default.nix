{
  clusterToken ? null,
  hypervisorClusterAddress,
  hypervisorClusterPeerAddresses ? "",
  hypervisorManagementAddress,
  hypervisorName,
  hypervisorRole ? "member",
  joined ? false,
  sourceDefault,
  sourceInstances,
  sourceIso,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  #########################################################
  # Variables
  #########################################################

  # Strip the port from the cluster address.
  hypervisorClusterIP = builtins.elemAt (lib.strings.splitString ":" hypervisorClusterAddress) 0;

  # Join the cluster addresses with commas and prefix tcp:
  hypervisorClusterAddressList =
    if hypervisorClusterPeerAddresses != "" then
      lib.strings.concatStringsSep "," (lib.map (addr: "tcp:${addr}") hypervisorClusterPeerAddresses)
    else
      "";

  # A string used in bash comparisons to determine if we are joining the cluster.
  joiningCluster = if clusterToken != null then "true" else "false";

  #########################################################
  # Global configuration
  #########################################################
  globalConfig = {

    #########################################################
    # Preseed configuration.
    #########################################################
    preseed = {

      #########################################################
      # Configuration.
      #########################################################
      config =
        if joined then
          {

            # Core
            "core.shutdown_timeout" = 5;

            # TODO: Debug ACME configuration with Cloudflare.
            # ACME
            #"acme.agree_tos" = true;
            #"acme.ca_url" = "https://acme-staging-v02.api.letsencrypt.org/directory";
            #"acme.ca_url" = "https://acme-v02.api.letsencrypt.org/directory";
            #"acme.challenge" = "DNS-01";
            #"acme.domain" = "saltlabs.cloud";
            #"acme.email" = "acme@saltlabs.cloud";
            #"acme.provider" = "cloudflare";
            #"acme.provider.resolvers" = "1.1.1.1,1.0.0.1";

            # Images
            "images.auto_update_interval" = 6;

            # Allow OVN controller to send logs to incus.
            "core.syslog_socket" = true;

          }
        else
          { };

      #########################################################
      # Projects
      #########################################################
      projects =
        if joined then
          [

            #########################################################
            # Default project.
            #########################################################
            {
              name = "default";
              description = "Default Incus project";
              config = {
                "features.images" = "true";
                "features.networks" = "true";
                "features.networks.zones" = "true";
                "features.profiles" = "true";
                "features.storage.buckets" = "true";
                "features.storage.volumes" = "true";
              };
            }

            #########################################################
            # Nutanix project.
            #########################################################
            {
              name = "nutanix";
              description = "Nutanix Community Edition";
              config = {
                "features.images" = "true";
                "features.networks" = "true";
                "features.networks.zones" = "true";
                "features.profiles" = "true";
                "features.storage.buckets" = "true";
                "features.storage.volumes" = "true";
                "restricted" = "false";
              };
            }
          ]
        else
          [ ];

      #########################################################
      # Networks.
      #########################################################
      networks =
        if joined then
          [

            #########################################################
            # Default Project Networks
            #########################################################

            ###########################
            # Bridge Network (transparent bridge)
            #
            # Reference: https://linuxcontainers.org/incus/docs/main/reference/network_bridge/
            ###########################
            {
              name = "incusbr0";
              type = "bridge";
              project = "default";
              config = {
                "bridge.driver" = "openvswitch";
                "dns.mode" = "none"; # none, managed, dynamic
                "ipv4.address" = "none";
                "ipv4.dhcp" = "false";
                "ipv4.nat" = "false";
                "ipv4.routing" = "false";
                "ipv6.address" = "none";
                "security.acls.default.egress.action" = "allow";
                "security.acls.default.ingress.action" = "allow";
              };
            }

            ###########################
            # Bridge Network (routed bridge)
            #
            # Reference: https://linuxcontainers.org/incus/docs/main/reference/network_bridge/
            ###########################
            {
              name = "incusbr1";
              type = "bridge";
              project = "default";
              config = {
                "bridge.driver" = "openvswitch";
                "dns.mode" = "managed"; # none, managed, dynamic
                "dns.domain" = "incus.local";
                "dns.nameservers" = "10.10.200.254";
                "ipv4.address" = "10.10.201.1/24";
                "ipv4.dhcp" = "true";
                "ipv4.dhcp.ranges" = "10.10.201.100-10.10.201.150";
                "ipv4.dhcp.routes" = "0.0.0.0/0,10.10.201.1";
                "ipv4.nat" = "false";
                "ipv4.ovn.ranges" = "10.10.201.2-10.10.201.50";
                "ipv4.routes" = "10.10.202.0/24,10.10.203.0/24,10.10.204.0/24,10.10.205.0/24";
                "ipv4.routing" = "true";
                "ipv6.address" = "none";
                "security.acls.default.egress.action" = "allow";
                "security.acls.default.ingress.action" = "allow";
              };
            }

            #########################################################
            # Nutanix Project Networks
            #########################################################

            ###########################
            # Nutanix VPC
            #
            # Reference: https://linuxcontainers.org/incus/docs/main/reference/network_ovn/
            ###########################
            {
              name = "nutanix-vpc";
              type = "ovn";
              project = "nutanix";
              config = {
                "dns.domain" = "nutanix.local";
                "dns.nameservers" = "10.10.200.254";
                "ipv4.address" = "10.10.202.1/24";
                "ipv4.dhcp" = "true";
                "ipv4.dhcp.ranges" = "10.10.202.100-10.10.202.150";
                "ipv4.dhcp.routes" = "0.0.0.0/0,10.10.202.1";
                "ipv4.nat" = "false";
                "ipv6.address" = "none";
                "network" = "incusbr1";
                "security.acls.default.egress.action" = "allow";
                "security.acls.default.ingress.action" = "allow";
              };
            }
          ]
        else
          [ ];

      #########################################################
      # Profiles.
      #########################################################
      profiles =
        if joined then
          [

            #########################################################
            # Default Project Profiles
            #########################################################

            ###########################
            # Default profile
            ###########################
            {
              name = "default";
              description = "Default profile";
              project = "default";
              config = {
                "limits.cpu" = 2;
                "limits.memory" = "2GiB";
              };
              devices = {
                root = {
                  path = "/";
                  pool = "default";
                  type = "disk";
                };
                eth0 = {
                  name = "eth0";
                  # Network and nictype are mutually exclusive.
                  network = "incusbr0";
                  type = "nic";
                };
              };
            }

            ###########################
            # System Containers
            ###########################
            {
              name = "system-containers";
              description = "System Containers profile";
              project = "default";
              config = {
                "limits.cpu" = 2;
                "limits.memory" = "2GiB";
              };
              devices = {
                root = {
                  path = "/";
                  pool = "instances";
                  type = "disk";
                };
                eth0 = {
                  name = "eth0";
                  # Network and nictype are mutually exclusive.
                  network = "incusbr1";
                  type = "nic";
                };
              };
            }

            ###########################
            # Application Containers
            ###########################
            {
              name = "application-containers";
              description = "Application Containers profile";
              project = "default";
              config = {
                "limits.cpu" = 2;
                "limits.memory" = "2GiB";
              };
              devices = {
                root = {
                  path = "/";
                  pool = "instances";
                  type = "disk";
                };
                eth0 = {
                  name = "eth0";
                  # Network and nictype are mutually exclusive.
                  network = "incusbr1";
                  type = "nic";
                };
              };
            }

            ###########################
            # Virtual Machines
            ###########################
            {
              name = "virtual-machines";
              description = "Virtual Machines profile";
              project = "default";
              config = {
                "limits.cpu" = 4;
                "limits.memory" = "4GiB";
                "security.nesting" = false;
                "security.secureboot" = false;
              };
              devices = {
                root = {
                  path = "/";
                  pool = "instances";
                  type = "disk";
                };
                eth0 = {
                  name = "eth0";
                  # Network and nictype are mutually exclusive.
                  network = "incusbr1";
                  type = "nic";
                };
              };
            }

            #########################################################
            # Nutanix Project Profiles
            #########################################################

            ###########################
            # Hypervisors profile
            ###########################
            {
              name = "hypervisors";
              description = "Profile for nested hypervisors";
              project = "nutanix";
              config = {
                "limits.cpu" = 8;
                "limits.memory" = "32GiB";
                "security.nesting" = true;
                "security.secureboot" = false;
                "security.syscalls.intercept.mknod" = true;
                "security.syscalls.intercept.setxattr" = true;
                "security.syscalls.intercept.sysinfo" = true;
              };
              devices = {
                root = {
                  path = "/";
                  pool = "instances";
                  type = "disk";
                };
                eth0 = {
                  name = "eth0";
                  # Network and nictype are mutually exclusive.
                  network = "nutanix-vpc";
                  type = "nic";
                };
              };
            }
          ]
        else
          [ ];

      #########################################################
      # Storage volumes.
      #########################################################
      storage_volumes =
        if joined then
          [

            #########################################################
            # Default Project Storage Volumes
            #########################################################

            # None required.

            #########################################################
            # Nutanix Project Storage Volumes
            #########################################################

            ###########################
            # NCE-01 Storage Volumes (HYPERVISOR-1)
            ###########################
            {
              name = "NCE-01-CVM";
              type = "custom";
              description = "NCE-01 CVM storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "250GiB";
              };
              content_type = "block";
            }
            {
              name = "NCE-01-DATA";
              type = "custom";
              description = "NCE-01 DATA storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "500GiB";
              };
              content_type = "block";
            }

            ###########################
            # NCE-02 Storage Volumes (HYPERVISOR-2)
            ###########################
            {
              name = "NCE-02-CVM";
              type = "custom";
              description = "NCE-02 CVM storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "250GiB";
              };
              content_type = "block";
            }
            {
              name = "NCE-02-DATA";
              type = "custom";
              description = "NCE-02 DATA storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "500GiB";
              };
              content_type = "block";
            }

            ###########################
            # NCE-03 Storage Volumes (HYPERVISOR-3)
            ###########################
            {
              name = "NCE-03-CVM";
              type = "custom";
              description = "NCE-03 CVM storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "250GiB";
              };
              content_type = "block";
            }
            {
              name = "NCE-03-DATA";
              type = "custom";
              description = "NCE-03 DATA storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "500GiB";
              };
              content_type = "block";
            }

            ###########################
            # NCE-04 Storage Volumes (HYPERVISOR-4)
            ###########################
            {
              name = "NCE-04-CVM";
              type = "custom";
              description = "NCE-04 CVM storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "250GiB";
              };
              content_type = "block";
            }
            {
              name = "NCE-04-DATA";
              type = "custom";
              description = "NCE-04 DATA storage volume";
              project = "nutanix";
              pool = "instances";
              config = {
                size = "500GiB";
              };
              content_type = "block";
            }

          ]
        else
          [ ];

    };

  };

  #########################################################
  # Host-specific configuration
  #########################################################
  hostConfig = {

    #########################################################
    # Preseed configuration.
    #########################################################
    preseed = {

      #########################################################
      # Configuration.
      #########################################################
      config = {

        # Management interface used by the API.
        "core.https_address" = hypervisorManagementAddress;

        # Cluster interface for backplane communication.
        "cluster.https_address" = hypervisorClusterAddress;

      };

      #########################################################
      # Cluster configuration.
      #########################################################
      cluster =
        if joined then
          {
            enabled = true;
            server_address = hypervisorClusterAddress;
            member_config = [
              #########################################################
              # Storage Pools
              #########################################################
              #########################
              # Default storage pool
              #########################
              {
                entity = "storage-pool";
                name = "default";
                key = "source";
                value = sourceDefault;
              }
              {
                entity = "storage-pool";
                name = "default";
                key = "source.wipe";
                value = "true";
              }
              #########################
              # Instances storage pool
              #########################
              {
                entity = "storage-pool";
                name = "instances";
                key = "source";
                value = sourceInstances;
              }
              {
                entity = "storage-pool";
                name = "instances";
                key = "source.wipe";
                value = "true";
              }
              #########################
              # ISO storage pool
              #########################
              {
                entity = "storage-pool";
                name = "iso";
                key = "source";
                value = sourceIso;
              }
              {
                entity = "storage-pool";
                name = "iso";
                key = "source.wipe";
                value = "true";
              }
              #########################################################
              # Networks
              #########################################################
              # Bridge Network (transparent bridge)
              #{
              #  entity = "network";
              #  name = "incusbr0";
              #  key = "bridge.external_interfaces";
              #  value = "bond0";
              #}
            ];
          }
          // lib.optionalAttrs (hypervisorRole == "bootstrap") {
            # The bootstrap server node requires a server_name.
            server_name = hypervisorName;
          }
          // lib.optionalAttrs (hypervisorRole == "member" && clusterToken != null) {
            # The cluster token is only needed for the initial bootstrap.
            cluster_token = clusterToken;
          }
        else
          {
            enabled = false;
          };

      #########################################################
      # Storage pools configuration.
      #########################################################
      storage_pools =
        if joined then
          [

            #########################
            # Default storage pool.
            #########################
            {
              name = "default";
              driver = "zfs";
              config = {
                "zfs.clone_copy" = "true";
                "zfs.export" = "false";
              };
            }

            #########################
            # Instances storage pool.
            #########################
            {
              name = "instances";
              driver = "zfs";
              config = {
                "zfs.clone_copy" = "true";
                "zfs.export" = "false";
              };
            }

            #########################
            # ISO storage pool.
            #########################
            {
              name = "iso";
              driver = "zfs";
              config = {
                "zfs.clone_copy" = "true";
                "zfs.export" = "false";
              };
            }

          ]
        else
          [ ];
    };
  };

  #########################################################
  # Merge global and host configurations
  #########################################################
  mergedConfig = {
    preseed = lib.recursiveUpdate globalConfig.preseed hostConfig.preseed;
  };

in
{

  #########################################################
  # NOTES
  #
  # - instance types:
  #    - system container: pet containers, shared kernel.
  #    - application container: docker-like containers.
  #    - virtual machine: full virtual machines, isolated kernel.
  #
  # - docs
  #   https://wiki.nixos.org/wiki/Incus
  #   https://nixos.wiki/wiki/Incus
  #
  # - Launch a container with:
  #   incus launch images:nixos/unstable nixos -c security.nesting=true
  #
  # - Launch a virtual machine with:
  #   incus launch --vm images:nixos/unstable nixos -c security.secureboot=false
  #
  #########################################################

  imports = [ ];

  environment.systemPackages = with pkgs; [
    ovn
  ];

  # Set Open vSwitch environment variables for correct socket paths
  environment.variables = {
    OVS_RUNDIR = "/run/openvswitch";
    OVN_RUNDIR = "/run/ovn";
  };

  programs = {
    bash = {
      # Add shell aliases for Open vSwitch commands
      shellAliases = {
        ovs-vsctl = "ovs-vsctl --db=unix:/run/openvswitch/db.sock";
      };
    };
  };

  virtualisation = {

    #########################################################
    # Open vSwitch
    #########################################################
    vswitch = {
      enable = true;
      resetOnStart = false;
    };

    #########################################################
    # Incus
    #########################################################

    incus = {
      enable = true;

      # Current LTS (6.0.4) doesn't work with Lego.
      #package = pkgs.incus-lts;
      package = pkgs.incus;

      startTimeout = 900; # 15 minutes
      socketActivation = false;
      softDaemonRestart = true;

      agent = {
        enable = false;
      };

      ui = {
        enable = true;
      };

      preseed = {
        inherit (mergedConfig.preseed)
          cluster
          config
          networks
          profiles
          projects
          storage_pools
          storage_volumes
          ;
      };
    };
  };

  #########################################################
  # OVN (Open Virtual Network) Services
  #########################################################

  systemd = {
    # Override global systemd timeouts for hypervisor systems
    extraConfig = ''
      DefaultTimeoutStartSec=300s
      DefaultTimeoutStopSec=90s
      DefaultLimitNOFILE=1048576
    '';

    # Custom target for coordinating OVN and Incus startup
    # Make sure all OVN and OVS services are ready before starting Incus.
    targets = {
      sdn-ready = {
        description = "OVN services are ready";
        after = [
          # OVN services
          "ovn-controller.service"
          "ovn-northd.service"
          "ovn-nb-ovsdb.service"
          "ovn-sb-ovsdb.service"

          # OVS services
          "ovs-vswitchd.service"
        ];
        wants = [
          # OVN services
          "ovn-controller.service"
          "ovn-northd.service"
          "ovn-nb-ovsdb.service"
          "ovn-sb-ovsdb.service"

          # OVS services
          "ovs-vswitchd.service"
        ];
        wantedBy = [ "multi-user.target" ];
      };
    };

    services = {

      #########################################################
      # Open Virtual Network
      #########################################################

      ###############################
      # OVN Northd
      #
      # This service translates high-level OVN configuration
      # into logical configuration for ovn-controller
      #
      ###############################
      ovn-northd = {
        description = "OVN northd";
        after = [
          # Wait for Network
          "network.target"

          # Wait for Open vSwitch
          "ovs-vswitchd.service"

          # Wait for OVN Databases
          "ovn-nb-ovsdb.service"
          "ovn-sb-ovsdb.service"
        ];
        requires = [
          # Requires Open vSwitch
          "ovs-vswitchd.service"

          # Requires OVN Databases
          "ovn-nb-ovsdb.service"
          "ovn-sb-ovsdb.service"
        ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${pkgs.ovn}/bin/ovn-northd --pidfile=/run/ovn/ovn-northd.pid --detach --log-file=/var/log/ovn/ovn-northd.log --ovnnb-db=unix:/run/ovn/ovnnb_db.sock --ovnsb-db=unix:/run/ovn/ovnsb_db.sock --ovn-encap-ip=${hypervisorClusterIP}";
          PIDFile = "/run/ovn/ovn-northd.pid";
          User = "root";
          RuntimeDirectory = "ovn";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          LogsDirectory = "ovn";
          LogsDirectoryMode = "0755";
          TimeoutStartSec = 60;
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [ "OVN_RUNDIR=/run/ovn" ];
        };

        preStart = ''
          ${pkgs.coreutils}/bin/mkdir -p /run/ovn
          # Wait for database services to be fully ready
          for i in {1..30}; do
            if ${pkgs.ovn}/bin/ovn-nbctl --timeout=5 list nb_global >/dev/null 2>&1 && \
              ${pkgs.ovn}/bin/ovn-sbctl --timeout=5 list sb_global >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done
        '';
      };

      ###############################
      # OVN Northbound
      #
      # This database is the interface between
      # OVN and Incus.
      #
      ###############################
      ovn-nb-ovsdb = {
        description = "OVN Northbound DB";
        after = [ "network.target" ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/run/ovn/ovn-nb-db.ctl --pidfile=/run/ovn/ovnnb_db.pid --detach --log-file=/var/log/ovn/ovnnb_db.log --remote=punix:/run/ovn/ovnnb_db.sock --remote=ptcp:6641:127.0.0.1 /var/lib/ovn/ovnnb_db.db";
          PIDFile = "/run/ovn/ovnnb_db.pid";
          User = "root";
          RuntimeDirectory = "ovn";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          StateDirectory = "ovn";
          StateDirectoryMode = "0755";
          LogsDirectory = "ovn";
          LogsDirectoryMode = "0755";
          TimeoutStartSec = 60;
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [ "OVN_RUNDIR=/run/ovn" ];
        };

        preStart = ''
          ${pkgs.coreutils}/bin/mkdir -p /run/ovn
          if [ ! -f /var/lib/ovn/ovnnb_db.db ]; then
            ${pkgs.ovn}/bin/ovsdb-tool create /var/lib/ovn/ovnnb_db.db ${pkgs.ovn}/share/ovn/ovn-nb.ovsschema
          fi
        '';
      };

      ###############################
      # OVN Southbound DB
      #
      # This database stores the configuration
      # consumed by ovn-controller.
      #
      ###############################
      ovn-sb-ovsdb = {
        description = "OVN Southbound DB";
        after = [ "network.target" ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          #ExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/run/ovn/ovn-sb-db.ctl --pidfile=/run/ovn/ovnsb_db.pid --detach --log-file=/var/log/ovn/ovnsb_db.log --remote=punix:/run/ovn/ovnsb_db.sock --remote=ptcp:6642:127.0.0.1 /var/lib/ovn/ovnsb_db.db";
          ExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/run/ovn/ovn-sb-db.ctl --pidfile=/run/ovn/ovnsb_db.pid --detach --log-file=/var/log/ovn/ovnsb_db.log --remote=punix:/run/ovn/ovnsb_db.sock --remote=ptcp:6642:0.0.0.0 /var/lib/ovn/ovnsb_db.db";
          PIDFile = "/run/ovn/ovnsb_db.pid";
          User = "root";
          RuntimeDirectory = "ovn";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          StateDirectory = "ovn";
          StateDirectoryMode = "0755";
          LogsDirectory = "ovn";
          LogsDirectoryMode = "0755";
          TimeoutStartSec = 60;
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [ "OVN_RUNDIR=/run/ovn" ];
        };

        preStart = ''
          ${pkgs.coreutils}/bin/mkdir -p /run/ovn
          if [ ! -f /var/lib/ovn/ovnsb_db.db ]; then
            ${pkgs.ovn}/bin/ovsdb-tool create /var/lib/ovn/ovnsb_db.db ${pkgs.ovn}/share/ovn/ovn-sb.ovsschema
          fi
        '';
      };

      ###############################
      # OVN Controller
      #
      # The local controller connects to the
      # southbound database.
      #
      ###############################
      ovn-controller = {
        description = "OVN Controller";
        after = [
          # Wait for Network
          "network.target"

          # Wait for Open vSwitch
          "ovs-vswitchd.service"

          # Wait for OVN Services
          "ovn-nb-ovsdb.service"
          "ovn-sb-ovsdb.service"
          "ovn-northd.service"
        ];
        requires = [
          # Requires Open vSwitch
          "ovs-vswitchd.service"

          # Requires OVN Databases
          "ovn-nb-ovsdb.service"
          "ovn-sb-ovsdb.service"
        ];
        wants = [ "ovn-northd.service" ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${pkgs.ovn}/bin/ovn-controller --pidfile=/run/ovn/ovn-controller.pid --detach --log-file=/var/log/ovn/ovn-controller.log unix:/run/openvswitch/db.sock";
          PIDFile = "/run/ovn/ovn-controller.pid";
          User = "root";
          RuntimeDirectory = "ovn";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          LogsDirectory = "ovn";
          LogsDirectoryMode = "0755";
          TimeoutStartSec = 60;
          Restart = "on-failure";
          RestartSec = 10;
          Environment = [
            "OVS_RUNDIR=/var/run/openvswitch"

            # Allow OVN controller to send logs to incus.
            "OVN_CTL_OPTS=--ovn-controller-log='-vsyslog:info --syslog-method=unix:/var/lib/incus/syslog.socket'"
          ];
        };

        preStart = ''
          # Set variables based on cluster membership status
          if [[ "${lib.boolToString joined}" == "true" ]];
          then
            if [[ -n "${hypervisorClusterAddressList}" ]];
            then
              OVN_SOUTHBOUND_USE_REMOTE=true
            else
              OVN_SOUTHBOUND_USE_REMOTE=false
            fi
          else
            OVN_SOUTHBOUND_USE_REMOTE=false
          fi
          ${pkgs.coreutils}/bin/echo "OVN Southbound DB using remote: ''${OVN_SOUTHBOUND_USE_REMOTE}"

          # Wait for OVS to be fully ready
          for i in {1..30}; do
            ${pkgs.coreutils}/bin/echo "Waiting for OVS to be ready..."
            if ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock --timeout=5 show >/dev/null 2>&1; then
              break
            fi
            sleep 10
          done
          ${pkgs.coreutils}/bin/echo "OVS is ready."

          # Set a system ID for OVN
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:system-id=${hypervisorName}"

          # Set the OVN encapsulation IP for geneve tunnels
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:ovn-encap-ip=${hypervisorClusterIP}"
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:ovn-encap-type=geneve"

          # Point OVN to the correct OVN Southbound DB
          if [[ "''${OVN_SOUTHBOUND_USE_REMOTE}" == "true" ]];
          then
            ${pkgs.coreutils}/bin/echo "OVN Southbound DB using remote: ${hypervisorClusterAddressList}"
            ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:ovn-remote=${hypervisorClusterAddressList}"
          else
            ${pkgs.coreutils}/bin/echo "OVN Southbound DB using local: unix:/run/ovn/ovnsb_db.sock"
            ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:ovn-remote=unix:/run/ovn/ovnsb_db.sock"
          fi

          # Set additional OVN configuration
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:ovn-bridge=br-int"

          # Create the main OVS integration bridge
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock --may-exist add-br br-int

          # Bring up the integration bridge
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set interface br-int admin_state=up

          # Ensure the bridge is properly configured
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set bridge br-int fail_mode=secure

          # Wait for OVN Northbound database socket to be available
          for i in {1..30}; do
            ${pkgs.coreutils}/bin/echo "Waiting for OVN Northbound database socket to be available..."
            if [ -S /run/ovn/ovnnb_db.sock ];
            then
              break
            fi
            sleep 10
          done
          ${pkgs.coreutils}/bin/echo "OVN Northbound database socket is available."

          # Wait for OVN Southbound database socket to be available
          for i in {1..30}; do
            ${pkgs.coreutils}/bin/echo "Waiting for OVN Southbound database socket to be available..."
            if [ -S /run/ovn/ovnsb_db.sock ];
            then
              break
            fi
            sleep 10
          done
          ${pkgs.coreutils}/bin/echo "OVN Southbound database socket is available."
        '';
      };

      #########################################################
      # Incus Service Override
      #########################################################
      incus = lib.mkMerge [
        (lib.mkIf (config.virtualisation.incus.preseed != null) {

          description = lib.mkForce "Incus Container and Virtual Machine Management Daemon (customised)";

          after = lib.mkAfter [
            "sdn-ready.target"

            # Requires SOPS
            "sops-nix.service"
          ];
          wants = lib.mkAfter [
            "sdn-ready.target"
          ];

          serviceConfig = {
            EnvironmentFile = config.sops.templates."incus-acme.env".path;
          };

          preStart = ''
            # Show the Incus version
            ${pkgs.coreutils}/bin/echo "Starting Incus version: $(incus --version)"

            # Check for lego in the PATH
            ${pkgs.coreutils}/bin/echo "Checking for lego in the PATH..."
            ${pkgs.coreutils}/bin/echo "lego: $(${pkgs.which}/bin/which lego)"
            ${pkgs.coreutils}/bin/echo "$(lego --version || ${pkgs.coreutils}/bin/echo "lego not found")"

            # Verify Cloudflare credentials are properly configured
            ${pkgs.coreutils}/bin/echo "Checking Cloudflare credentials..."

            # Check for DNS API Token (preferred method)
            if [[ "''${CLOUDFLARE_DNS_API_TOKEN:-EMPTY}" != "EMPTY" ]]; then
              ${pkgs.coreutils}/bin/echo "✓ Using Cloudflare DNS API Token (length: ''${#CLOUDFLARE_DNS_API_TOKEN} characters)"
            # Check for Email + API Key (legacy method)
            elif [[ "''${CLOUDFLARE_EMAIL:-EMPTY}" != "EMPTY" && "''${CLOUDFLARE_API_KEY:-EMPTY}" != "EMPTY" ]]; then
              ${pkgs.coreutils}/bin/echo "✓ Using Cloudflare Email + API Key method"
              ${pkgs.coreutils}/bin/echo "  Email: ''${CLOUDFLARE_EMAIL}"
              ${pkgs.coreutils}/bin/echo "  API Key: (length: ''${#CLOUDFLARE_API_KEY} characters)"
            else
              ${pkgs.coreutils}/bin/echo "⚠️  WARNING: No Cloudflare credentials have been set!"
              ${pkgs.coreutils}/bin/echo "   Either set CLOUDFLARE_DNS_API_TOKEN (recommended)"
              ${pkgs.coreutils}/bin/echo "   Or set both CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY"
            fi

            # Wait up to 15 minutes for the chassis to appear.
            ${pkgs.coreutils}/bin/echo "Waiting for OVN chassis '${hypervisorName}' to be registered..."
            for i in {1..90}; do
              CHASSIS_FOUND=false
              CHASSIS_FOUND=$( (${pkgs.ovn}/bin/ovn-sbctl --format=json --timeout=3 list chassis | ${pkgs.jq}/bin/jq -r '.data[][] | select(type=="string")' | ${pkgs.gnugrep}/bin/grep -q -x "${hypervisorName}") || true )
              if [[ $? -eq 0 && "''${CHASSIS_FOUND}" != "false" ]]; then
                ${pkgs.coreutils}/bin/echo "OVN chassis found. Proceeding with Incus start."
                sleep 10
                exit 0
              fi
              ${pkgs.coreutils}/bin/echo "Attempt $i: OVN chassis not yet found, waiting 10s..."
              sleep 10
            done
            ${pkgs.coreutils}/bin/echo "Warning: Timed out waiting for OVN chassis. Incus may still fail to initialize networks."
          '';
        })
      ];

      #########################################################
      # Incus Preseed Service Override
      #########################################################
      incus-preseed = lib.mkMerge [
        (lib.mkIf (config.virtualisation.incus.preseed != null) {

          description = lib.mkForce "Incus initialization with preseed file (customised)";

          after = lib.mkAfter [
            "sdn-ready.target"

            # Requires SOPS
            "sops-nix.service"
          ];
          wants = lib.mkAfter [
            "sdn-ready.target"
          ];

          serviceConfig = {
            EnvironmentFile = config.sops.templates."incus-acme.env".path;
          };

          preStart = ''
            # Clean up any ZFS pools created in error.
            ${pkgs.coreutils}/bin/echo "Cleaning up invalid ZFS pools..."
            ${pkgs.zfs}/bin/zfs destroy -r default 2>/dev/null || ${pkgs.coreutils}/bin/echo "Pool not found default"
            ${pkgs.zfs}/bin/zfs destroy -r instances 2>/dev/null || ${pkgs.coreutils}/bin/echo "Pool not found instances"
            ${pkgs.zfs}/bin/zfs destroy -r iso 2>/dev/null || ${pkgs.coreutils}/bin/echo "Pool not found iso"

            # Wait for Network to be ready.
            ${pkgs.coreutils}/bin/echo "Waiting for network to be ready..."
            for i in {1..60}; do
              if [ -n "$(${pkgs.systemd}/bin/networkctl status --no-pager | ${pkgs.gnugrep}/bin/grep -E '[[:space:]]*Online state: (online|partial)')" ]; then
                ${pkgs.coreutils}/bin/echo "Network is ready."
                break
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done

            # Wait up to 60s for incus daemon to be fully responsive.
            ${pkgs.coreutils}/bin/echo "Preparing to apply Incus preseed..."
            READY=false
            for i in {1..10}; do
              if ${pkgs.incus}/bin/incus admin waitready --timeout=6; then
                ${pkgs.coreutils}/bin/echo "Incus daemon is ready."
                READY=true
                break
              fi
              sleep 6
            done
            if [ "$READY" != "true" ]; then
              ${pkgs.coreutils}/bin/echo "Warning: Timed out waiting for Incus daemon to be ready. Preseed may fail."
            fi

            # If this is a member node joining the cluster, wipe existing data.
            if [[ "${joiningCluster}" == "true" ]];
            then
              ${pkgs.coreutils}/bin/echo "Preparing for cluster member join, wiping existing data..."

              # Stop all instances (if any)
              ${pkgs.coreutils}/bin/echo "Stopping all instances..."
              ${pkgs.incus}/bin/incus stop --all --force-local --timeout=300 || true

              # Delete all instances
              ${pkgs.coreutils}/bin/echo "Deleting all instances..."
              for instance in $(${pkgs.incus}/bin/incus list -c n --format csv --force-local); do
                ${pkgs.incus}/bin/incus delete --force "$instance" --force-local || true
              done

              # Remove default profile devices
              ${pkgs.coreutils}/bin/echo "Removing default profile devices..."
              ${pkgs.incus}/bin/incus profile device remove default root --force-local || true
              ${pkgs.incus}/bin/incus profile device remove default eth0 --force-local || true

              # Delete networks
              ${pkgs.coreutils}/bin/echo "Deleting networks..."
              ${pkgs.incus}/bin/incus network delete incusbr0 --force-local || true
              ${pkgs.incus}/bin/incus network delete incusbr1 --force-local || true

              # Delete storage pools
              ${pkgs.coreutils}/bin/echo "Deleting storage pools..."
              ${pkgs.incus}/bin/incus storage delete default --force-local || true
              ${pkgs.incus}/bin/incus storage delete instances --force-local || true
              ${pkgs.incus}/bin/incus storage delete iso --force-local || true

              # Unset addresses
              ${pkgs.coreutils}/bin/echo "Unsetting addresses..."
              ${pkgs.incus}/bin/incus config unset core.https_address --force-local || true
              ${pkgs.incus}/bin/incus config unset cluster.https_address --force-local || true

              ${pkgs.coreutils}/bin/echo "Incus data wiped successfully."
            else
              ${pkgs.coreutils}/bin/echo "Not joining a cluster at this time, skipping data wipe."
              exit 0
            fi
          '';
        })
      ];

    };

  };

  networking = {
    nftables = {
      enable = true;
      tables = {
        #########################################################
        # Forwarding Rules
        #########################################################
        forwarding = {
          family = "ip";
          content = ''
            chain forward {
              type filter hook forward priority 0; policy accept;

              # Allow forwarding from bond0 to bridges (inbound to instances)
              iifname "bond0" oifname "incusbr0" accept  # Transparent bridge
              iifname "bond0" oifname "incusbr1" accept  # Routed bridge

              # Allow forwarding from both bridges to bond0 (outbound from instances)
              iifname "incusbr0" oifname "bond0" ct state established,related accept
              iifname "incusbr1" oifname "bond0" ct state established,related accept

              # Allow forwarding between bridges and management interface
              iifname "incusbr0" oifname "enp6s0" accept
              iifname "incusbr1" oifname "enp6s0" accept
              iifname "enp6s0" oifname "incusbr0" accept
              iifname "enp6s0" oifname "incusbr1" accept

              # Allow forwarding between the two bridges
              iifname "incusbr0" oifname "incusbr1" accept
              iifname "incusbr1" oifname "incusbr0" accept
            }
          '';
        };
        #########################################################
        # Incus Dataplane Rules (10.10.200.0/24)
        #########################################################
        incus = {
          family = "ip";
          content = ''
            chain input {
              type filter hook input priority 0; policy accept;

              # Allow Incus dataplane traffic from all nodes
              ip saddr 10.10.200.0/24 tcp dport 9443 accept

              # Allow ICMP traffic from all nodes
              ip saddr 10.10.200.0/24 ip protocol icmp accept
            }
          '';
        };
        #########################################################
        # Management Network Rules (10.10.1.0/24)
        #########################################################
        management = {
          family = "ip";
          content = ''
            chain input {
              type filter hook input priority 0; policy accept;

              # TODO: Lockdown when done testing.
              # YOLO allow all traffic from management network (10.10.1.0/24)
              ip saddr 10.10.1.0/24 accept

              # Allow SSH from management
              ip saddr 10.10.1.0/24 tcp dport 22 accept

              # Allow Incus API ports from management
              ip saddr 10.10.1.0/24 tcp dport 8443 accept
              ip saddr 10.10.1.0/24 tcp dport 9443 accept

              # Allow ICMP traffic from management
              ip saddr 10.10.1.0/24 ip protocol icmp accept
            }
          '';
        };
        #########################################################
        # Platform Network Rules (10.10.100.0/24)
        #########################################################
        platform = {
          family = "ip";
          content = ''
            chain input {
              type filter hook input priority 0; policy accept;

              # TODO: Lockdown when done testing.
              # YOLO allow all traffic from platform network (10.10.100.0/24)
              ip saddr 10.10.100.0/24 accept

              # Allow SSH from platform
              ip saddr 10.10.100.0/24 tcp dport 22 accept

              # Allow Incus API ports from platform
              ip saddr 10.10.100.0/24 tcp dport 8443 accept
              ip saddr 10.10.100.0/24 tcp dport 9443 accept

              # Allow ICMP traffic from platform
              ip saddr 10.10.100.0/24 ip protocol icmp accept
            }
          '';
        };
        #########################################################
        # Applications Network Rules (via bond0 to 10.10.201.0/24-10.10.205.0/24)
        #########################################################
        applications = {
          family = "ip";
          content = ''
            chain input {
              type filter hook input priority 0; policy accept;

              # Allow HTTP from anywhere for exposed applications on bond0 only
              iifname "bond0" ip saddr 0.0.0.0/0 tcp dport 80 accept

              # Allow HTTPS from anywhere for exposed applications on bond0 only
              iifname "bond0" ip saddr 0.0.0.0/0 tcp dport 443 accept
            }
          '';
        };
      };
    };
    firewall = {
      enable = false;
      trustedInterfaces = [
        "lo" # Loopback
        "enp6s0" # Management interface
        "incusbr0" # Transparent bridge
        "incusbr1" # Routed bridge
        "bond0" # Bond interface
      ];
      allowedTCPPorts = [
        22 # SSH
        80 # HTTP
        443 # HTTPS
        8443 # Incus API
        9443 # Incus UI
        6642 # OVN SB DB
      ];
      # Allow ICMP globally
      allowPing = true;
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
