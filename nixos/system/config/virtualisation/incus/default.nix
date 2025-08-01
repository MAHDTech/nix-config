{
  hypervisor ? {
    name = null;
  },
  incus ? {
    joined = false;
    role = null;
    managementAddress = null;
    clusterAddress = null;
    clusterToken = null;
  },
  ovn ? {
    joined = false;
    clusterAddresses = [ ];
  },
  zfs ? {
    sourceDefault = null;
    sourceInstances = null;
    sourceIso = null;
  },
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

  #########################
  # Hypervisor configuration
  #########################

  inherit (hypervisor) name;
  hypervisorName = name;

  #########################
  # Incus configuration
  #########################

  inherit (incus)
    joined
    role
    managementAddress
    clusterAddress
    clusterToken
    ;
  incusJoined = joined;
  hypervisorRole = role;
  hypervisorManagementAddress = managementAddress;
  hypervisorClusterAddress = clusterAddress;

  # Strip the port from the cluster address.
  hypervisorClusterIP = builtins.elemAt (lib.strings.splitString ":" hypervisorClusterAddress) 0;

  # Bootstrap IP for member nodes (extracted from first cluster address where role is bootstrap)
  bootstrapIP =
    if hypervisorRole == "member" && ovn.clusterAddresses != [ ] then
      builtins.head ovn.clusterAddresses # Use first cluster member as bootstrap
    else
      null;

  #########################
  # ZFS sources
  #########################

  inherit (zfs) sourceDefault sourceInstances sourceIso;
  zfsSourceDefault = sourceDefault;
  zfsSourceInstances = sourceInstances;
  zfsSourceIso = sourceIso;

  #########################
  # OVN configuration
  #########################

  ovnJoined = ovn.joined;
  ovnClusterAddresses = ovn.clusterAddresses;

  ovnConfig = {

    # OVN Northbound configuration.
    northbound = {
      port = 6641;
      addressList = lib.strings.concatStringsSep "," (
        lib.map (addr: "tcp:${addr}:${toString ovnConfig.northbound.port}") ovnClusterAddresses
      );

      # Use different database files for local vs cluster mode
      dbFile = "/var/lib/ovn/ovnnb_db.db";

      # Local mode: simple standalone database
      localExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/var/run/ovn/ovn-nb-db.ctl --pidfile=/var/run/ovn/ovnnb_db.pid --detach --log-file=/var/log/ovn/ovnnb_db.log --remote=punix:/var/run/ovn/ovnnb_db.sock ${ovnConfig.northbound.dbFile}";

      # Cluster mode: clustered database (TCP handled by RAFT internally)
      clusterExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/var/run/ovn/ovn-nb-db.ctl --pidfile=/var/run/ovn/ovnnb_db.pid --detach --log-file=/var/log/ovn/ovnnb_db.log --remote=punix:/var/run/ovn/ovnnb_db.sock ${ovnConfig.northbound.dbFile}";
    };

    # OVN Central configuration.
    central = {
      # Local mode: connect to local Unix socket
      localExecStart = "${pkgs.ovn}/bin/ovn-northd --pidfile=/var/run/ovn/ovn-central.pid --detach --log-file=/var/log/ovn/ovn-central.log --ovnnb-db=unix:/var/run/ovn/ovnnb_db.sock --ovnsb-db=unix:/var/run/ovn/ovnsb_db.sock";

      # Cluster mode: connect to cluster addresses for HA
      clusterExecStart = "${pkgs.ovn}/bin/ovn-northd --pidfile=/var/run/ovn/ovn-central.pid --detach --log-file=/var/log/ovn/ovn-central.log --ovnnb-db=${ovnConfig.northbound.addressList} --ovnsb-db=${ovnConfig.southbound.addressList}";
    };

    # OVN Southbound configuration.
    southbound = {
      port = 6642;
      addressList = lib.strings.concatStringsSep "," (
        lib.map (addr: "tcp:${addr}:${toString ovnConfig.southbound.port}") ovnClusterAddresses
      );

      # Use different database files for local vs cluster mode
      dbFile = "/var/lib/ovn/ovnsb_db.db";

      # Local mode: simple standalone database
      localExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/var/run/ovn/ovn-sb-db.ctl --pidfile=/var/run/ovn/ovnsb_db.pid --detach --log-file=/var/log/ovn/ovnsb_db.log --remote=punix:/var/run/ovn/ovnsb_db.sock ${ovnConfig.southbound.dbFile}";

      # Cluster mode: clustered database (TCP handled by RAFT internally)
      clusterExecStart = "${pkgs.ovn}/bin/ovsdb-server --unixctl=/var/run/ovn/ovn-sb-db.ctl --pidfile=/var/run/ovn/ovnsb_db.pid --detach --log-file=/var/log/ovn/ovnsb_db.log --remote=punix:/var/run/ovn/ovnsb_db.sock ${ovnConfig.southbound.dbFile}";
    };

  };

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
        if incusJoined then
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

            # Incus OVN configuration.
            "network.ovn.northbound_connection" =
              if ovnConfig.northbound.addressList != "" then "${ovnConfig.northbound.addressList}" else "";

          }
        else
          { };

      #########################################################
      # Projects
      #########################################################
      projects =
        if incusJoined then
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
        if incusJoined then
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
            #{
            #  name = "nutanix-vpc";
            #  type = "ovn";
            #  project = "nutanix";
            #  config = {
            #    "dns.domain" = "nutanix.local";
            #    "dns.nameservers" = "10.10.200.254";
            #    "ipv4.address" = "10.10.202.1/24";
            #    "ipv4.dhcp" = "true";
            #    "ipv4.dhcp.ranges" = "10.10.202.100-10.10.202.150";
            #    "ipv4.dhcp.routes" = "0.0.0.0/0,10.10.202.1";
            #    "ipv4.nat" = "false";
            #    "ipv6.address" = "none";
            #    "network" = "incusbr1";
            #    "security.acls.default.egress.action" = "allow";
            #    "security.acls.default.ingress.action" = "allow";
            #  };
            #}
          ]
        else
          [ ];

      #########################################################
      # Profiles.
      #########################################################
      profiles =
        if incusJoined then
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
            #{
            #  name = "hypervisors";
            #  description = "Profile for nested hypervisors";
            #  project = "nutanix";
            #  config = {
            #    "limits.cpu" = 8;
            #    "limits.memory" = "32GiB";
            #    "security.nesting" = true;
            #    "security.secureboot" = false;
            #    "security.syscalls.intercept.mknod" = true;
            #    "security.syscalls.intercept.setxattr" = true;
            #    "security.syscalls.intercept.sysinfo" = true;
            #  };
            #  devices = {
            #    root = {
            #      path = "/";
            #      pool = "instances";
            #      type = "disk";
            #    };
            #    eth0 = {
            #      name = "eth0";
            #      # Network and nictype are mutually exclusive.
            #      network = "nutanix-vpc";
            #      type = "nic";
            #    };
            #  };
            #}
          ]
        else
          [ ];

      #########################################################
      # Storage volumes.
      #########################################################
      storage_volumes =
        if incusJoined then
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
            #{
            #  name = "NCE-01-CVM";
            #  type = "custom";
            #  description = "NCE-01 CVM storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "250GiB";
            #  };
            #  content_type = "block";
            #}
            #{
            #  name = "NCE-01-DATA";
            #  type = "custom";
            #  description = "NCE-01 DATA storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "500GiB";
            #  };
            #  content_type = "block";
            #}

            ###########################
            # NCE-02 Storage Volumes (HYPERVISOR-2)
            ###########################
            #{
            #  name = "NCE-02-CVM";
            #  type = "custom";
            #  description = "NCE-02 CVM storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "250GiB";
            #  };
            #  content_type = "block";
            #}
            #{
            #  name = "NCE-02-DATA";
            #  type = "custom";
            #  description = "NCE-02 DATA storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "500GiB";
            #  };
            #  content_type = "block";
            #}

            ###########################
            # NCE-03 Storage Volumes (HYPERVISOR-3)
            ###########################
            #{
            #  name = "NCE-03-CVM";
            #  type = "custom";
            #  description = "NCE-03 CVM storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "250GiB";
            #  };
            #  content_type = "block";
            #}
            #{
            #  name = "NCE-03-DATA";
            #  type = "custom";
            #  description = "NCE-03 DATA storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "500GiB";
            #  };
            #  content_type = "block";
            #}

            ###########################
            # NCE-04 Storage Volumes (HYPERVISOR-4)
            ###########################
            #{
            #  name = "NCE-04-CVM";
            #  type = "custom";
            #  description = "NCE-04 CVM storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "250GiB";
            #  };
            #  content_type = "block";
            #}
            #{
            #  name = "NCE-04-DATA";
            #  type = "custom";
            #  description = "NCE-04 DATA storage volume";
            #  project = "nutanix";
            #  pool = "instances";
            #  config = {
            #    size = "500GiB";
            #  };
            #  content_type = "block";
            #}

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
        if incusJoined then
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
                value = zfsSourceDefault;
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
                value = zfsSourceInstances;
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
                value = zfsSourceIso;
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
        if incusJoined then
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

  environment = {
    systemPackages = with pkgs; [
      # Include the OVN CLI tools.
      pkgs.ovn
    ];

    # Set Open vSwitch environment variables for correct socket paths
    variables = {
      OVN_RUNDIR = "/run/ovn";
      OVS_RUNDIR = "/run/openvswitch";
    };
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
    # Make sure that Networking, OVN and OVS services are all ready before starting Incus.
    targets = {
      sdn-ready = {
        description = "OVN services are ready";
        after = [
          # Network must be online first
          "network-online.target"
          "systemd-networkd-wait-online.service"

          # OVN services
          "ovn-central.service"
          "ovn-controller.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"

          # OVS services
          "ovs-vswitchd.service"
          "ovsdb.service"

          # Custom OVN readiness check
          "ovn-readiness-check.service"
        ];
        wants = [
          # Pull in network-online to ensure network is ready
          "network-online.target"
          "systemd-networkd-wait-online.service"

          # OVN services
          "ovn-central.service"
          "ovn-controller.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"

          # OVS services
          "ovs-vswitchd.service"
          "ovsdb.service"

          # Custom OVN readiness check
          "ovn-readiness-check.service"
        ];
        wantedBy = [ "multi-user.target" ];
      };
    };

    # Custom service to validate OVN readiness
    services = {

      #########################################################
      # OVN Readiness Check
      #########################################################

      ovn-readiness-check = {
        description = "Validate OVN cluster connectivity";
        after = [
          "ovn-central.service"
          "ovn-controller.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"
          "ovs-vswitchd.service"
          "ovsdb.service"
        ];
        requires = [
          "ovn-central.service"
          "ovn-controller.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"
          "ovs-vswitchd.service"
          "ovsdb.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = ''
            ${pkgs.coreutils}/bin/echo "Waiting for OVN to be ready..."
            ${pkgs.coreutils}/bin/sleep 30

            # Check Northbound DB with retry
            ${pkgs.coreutils}/bin/echo "Checking Northbound DB..."
            while ! ${pkgs.ovn}/bin/ovn-nbctl --timeout=30 list nb_global >/dev/null 2>&1; do
              ${pkgs.coreutils}/bin/echo "Northbound DB is not ready, retrying in 10 seconds..."
              ${pkgs.coreutils}/bin/sleep 10
            done
            ${pkgs.coreutils}/bin/echo "Northbound DB is ready."

            # Check Southbound DB with retry
            ${pkgs.coreutils}/bin/echo "Checking Southbound DB..."
            while ! ${pkgs.ovn}/bin/ovn-sbctl --timeout=30 list sb_global >/dev/null 2>&1; do
              ${pkgs.coreutils}/bin/echo "Southbound DB is not ready, retrying in 10 seconds..."
              ${pkgs.coreutils}/bin/sleep 10
            done
            ${pkgs.coreutils}/bin/echo "Southbound DB is ready."

            # Check Open vSwitch with retry
            ${pkgs.coreutils}/bin/echo "Checking Open vSwitch..."
            while ! ${pkgs.ovn}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock get open_vswitch . external_ids:ovn-remote >/dev/null 2>&1; do
              ${pkgs.coreutils}/bin/echo "Open vSwitch is not ready, retrying in 10 seconds..."
              ${pkgs.coreutils}/bin/sleep 10
            done
            ${pkgs.coreutils}/bin/echo "Open vSwitch is ready."

            ${pkgs.coreutils}/bin/echo "OVN is ready."
          '';
          ExecStart = "${pkgs.coreutils}/bin/echo 'OVN is ready.'";
          RemainAfterExit = true;
          TimeoutStartSec = 60;
          Restart = "on-failure";
          RestartSec = 60;
        };
      };

      #########################################################
      # Open Virtual Network
      #########################################################

      ###############################
      # OVN Northbound DB
      #
      # This database is the interface between
      # OVN and Incus.
      #
      ###############################
      ovn-northbound-db = {
        description = "OVN Northbound DB";
        after = [
          "network.target"
          "systemd-networkd-wait-online.service"
        ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart =
            if ovnJoined then ovnConfig.northbound.clusterExecStart else ovnConfig.northbound.localExecStart;
          PIDFile = "/var/run/ovn/ovnnb_db.pid";
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
          ${pkgs.coreutils}/bin/mkdir -p /var/run/ovn /var/lib/ovn

          # Create initial database if it doesn't exist
          if [ ! -f ${ovnConfig.northbound.dbFile} ]; then
            ${pkgs.ovn}/bin/ovsdb-tool create ${ovnConfig.northbound.dbFile} ${pkgs.ovn}/share/ovn/ovn-nb.ovsschema
          fi
        ''
        + (
          if ovnJoined then
            ''
              # Cluster mode: Handle clustering based on role and current database state
              if ${pkgs.ovn}/bin/ovsdb-tool db-is-standalone ${ovnConfig.northbound.dbFile}; then
            ''
            + (
              if hypervisorRole == "bootstrap" then
                ''
                  ${pkgs.coreutils}/bin/echo "Converting standalone Northbound DB to a cluster..."
                  ${pkgs.ovn}/bin/ovsdb-tool create-cluster ${ovnConfig.northbound.dbFile}.new ${ovnConfig.northbound.dbFile} tcp:${hypervisorClusterIP}:${toString ovnConfig.northbound.port}
                  ${pkgs.coreutils}/bin/mv ${ovnConfig.northbound.dbFile}.new ${ovnConfig.northbound.dbFile}
                ''
              else if bootstrapIP != null then
                ''
                  ${pkgs.coreutils}/bin/echo "Converting standalone Northbound DB to join cluster..."
                  ${pkgs.ovn}/bin/ovsdb-tool join-cluster ${ovnConfig.northbound.dbFile}.new OVN_Northbound tcp:${hypervisorClusterIP}:${toString ovnConfig.northbound.port} tcp:${bootstrapIP}:${toString ovnConfig.northbound.port}
                  ${pkgs.coreutils}/bin/mv ${ovnConfig.northbound.dbFile}.new ${ovnConfig.northbound.dbFile}
                ''
              else
                ''
                  ${pkgs.coreutils}/bin/echo "Standalone Northbound DB, not forming a cluster."
                ''
            )
            + ''
              elif ${pkgs.ovn}/bin/ovsdb-tool db-is-clustered ${ovnConfig.northbound.dbFile}; then
                ${pkgs.coreutils}/bin/echo "Northbound DB is already clustered, skipping cluster setup."
              else
                ${pkgs.coreutils}/bin/echo "Unknown Northbound DB state, proceeding with caution."
              fi
            ''
          else
            ''
              # Local mode: No clustering setup needed
              ${pkgs.coreutils}/bin/echo "Running Northbound DB in local standalone mode."
            ''
        )
        + '''';
      };

      ###############################
      # OVN Southbound DB
      #
      # This database stores the configuration
      # consumed by ovn-controller.
      #
      ###############################
      ovn-southbound-db = {
        description = "OVN Southbound DB";
        after = [
          "network.target"
          "systemd-networkd-wait-online.service"
        ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart =
            if ovnJoined then ovnConfig.southbound.clusterExecStart else ovnConfig.southbound.localExecStart;
          PIDFile = "/var/run/ovn/ovnsb_db.pid";
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
          ${pkgs.coreutils}/bin/mkdir -p /var/run/ovn /var/lib/ovn

          # Create initial database if it doesn't exist
          if [ ! -f ${ovnConfig.southbound.dbFile} ]; then
            ${pkgs.ovn}/bin/ovsdb-tool create ${ovnConfig.southbound.dbFile} ${pkgs.ovn}/share/ovn/ovn-sb.ovsschema
          fi
        ''
        + (
          if ovnJoined then
            ''
              # Cluster mode: Handle clustering based on role and current database state
              if ${pkgs.ovn}/bin/ovsdb-tool db-is-standalone ${ovnConfig.southbound.dbFile}; then
            ''
            + (
              if hypervisorRole == "bootstrap" then
                ''
                  ${pkgs.coreutils}/bin/echo "Converting standalone Southbound DB to a cluster..."
                  ${pkgs.ovn}/bin/ovsdb-tool create-cluster ${ovnConfig.southbound.dbFile}.new ${ovnConfig.southbound.dbFile} tcp:${hypervisorClusterIP}:${toString ovnConfig.southbound.port}
                  ${pkgs.coreutils}/bin/mv ${ovnConfig.southbound.dbFile}.new ${ovnConfig.southbound.dbFile}
                ''
              else if bootstrapIP != null then
                ''
                  ${pkgs.coreutils}/bin/echo "Converting standalone Southbound DB to join cluster..."
                  ${pkgs.ovn}/bin/ovsdb-tool join-cluster ${ovnConfig.southbound.dbFile}.new OVN_Southbound tcp:${hypervisorClusterIP}:${toString ovnConfig.southbound.port} tcp:${bootstrapIP}:${toString ovnConfig.southbound.port}
                  ${pkgs.coreutils}/bin/mv ${ovnConfig.southbound.dbFile}.new ${ovnConfig.southbound.dbFile}
                ''
              else
                ''
                  ${pkgs.coreutils}/bin/echo "Standalone Southbound DB, not forming a cluster."
                ''
            )
            + ''
              elif ${pkgs.ovn}/bin/ovsdb-tool db-is-clustered ${ovnConfig.southbound.dbFile}; then
                ${pkgs.coreutils}/bin/echo "Southbound DB is already clustered, skipping cluster setup."
              else
                ${pkgs.coreutils}/bin/echo "Unknown Southbound DB state, proceeding with caution."
              fi
            ''
          else
            ''
              # Local mode: No clustering setup needed
              ${pkgs.coreutils}/bin/echo "Running Southbound DB in local standalone mode."
            ''
        )
        + '''';
      };

      ###############################
      # OVN Central
      #
      # This service syncs from northbound to southbound databases.
      # This is the service that runs northd.
      # In cluster mode this runs as active/standby with auto-failover.
      #
      ###############################
      ovn-central = {
        description = "OVN Central";
        after = [
          "network.target"
          "systemd-networkd-wait-online.service"
          "ovs-vswitchd.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"
        ];
        requires = [
          "ovs-vswitchd.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"
        ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart =
            if ovnJoined then ovnConfig.central.clusterExecStart else ovnConfig.central.localExecStart;
          PIDFile = "/var/run/ovn/ovn-central.pid";
          User = "root";
          RuntimeDirectory = "ovn";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          LogsDirectory = "ovn";
          LogsDirectoryMode = "0755";
          TimeoutStartSec = 60;
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [
            "OVN_RUNDIR=/var/run/ovn"
            "OVN_CTL_OPTS=\
            --ovn-northd-log='-vsyslog:info --syslog-method=unix:/var/lib/incus/syslog.socket' \
            --ovn-nb-log='-vsyslog:info --syslog-method=unix:/var/lib/incus/syslog.socket' \
            --ovn-sb-log='-vsyslog:info --syslog-method=unix:/var/lib/incus/syslog.socket'"
          ];
        };

        preStart = ''
          ${pkgs.coreutils}/bin/mkdir -p /var/run/ovn

          # In cluster mode, ovn-northd will handle cluster connectivity automatically
          if [[ "${lib.boolToString ovnJoined}" == "true" ]]; then
            ${pkgs.coreutils}/bin/echo "Cluster mode: ovn-northd will connect to cluster addresses"
            ${pkgs.coreutils}/bin/echo "Northbound cluster: ${ovnConfig.northbound.addressList}"
            ${pkgs.coreutils}/bin/echo "Southbound cluster: ${ovnConfig.southbound.addressList}"
          else
            # Local mode: Wait for local database services to be ready
          for i in {1..30}; do
              ${pkgs.coreutils}/bin/echo "Waiting for local OVN databases..."
            if ${pkgs.ovn}/bin/ovn-nbctl --timeout=5 list nb_global >/dev/null 2>&1 && \
              ${pkgs.ovn}/bin/ovn-sbctl --timeout=5 list sb_global >/dev/null 2>&1; then
              break
            fi
            sleep 10
          done
          fi
        '';
      };

      ###############################
      # OVN Controller
      #
      # Controller that interfaces from OVN to OVS.
      #
      ###############################
      ovn-controller = {
        description = "OVN Controller";
        after = [
          # Wait for Network
          "network.target"
          "systemd-networkd-wait-online.service"

          # Wait for Open vSwitch
          "ovs-vswitchd.service"

          # Wait for OVN Services
          "ovn-central.service"
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"
        ];
        requires = [
          # Requires Open vSwitch
          "ovs-vswitchd.service"

          # Requires OVN Databases
          "ovn-northbound-db.service"
          "ovn-southbound-db.service"
        ];
        wants = [ "ovn-central.service" ];
        wantedBy = [
          "multi-user.target"
          "sdn-ready.target"
        ];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${pkgs.ovn}/bin/ovn-controller --pidfile=/var/run/ovn/ovn-controller.pid --detach --log-file=/var/log/ovn/ovn-controller.log unix:/run/openvswitch/db.sock";
          PIDFile = "/var/run/ovn/ovn-controller.pid";
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
            "OVN_CTL_OPTS=\
              --ovn-controller-log='-vsyslog:info --syslog-method=unix:/var/lib/incus/syslog.socket'"
          ];
        };

        preStart = ''
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

          # Point OVN controller to local Southbound DB socket
          # NOTE: ovn-controller should ALWAYS use local socket, never cluster TCP addresses
          # The cluster TCP addresses are for RAFT peer communication between DB servers only
          ${pkgs.coreutils}/bin/echo "OVN Southbound DB using local socket: unix:/var/run/ovn/ovnsb_db.sock"
          ${pkgs.openvswitch}/bin/ovs-vsctl --db=unix:/run/openvswitch/db.sock set open_vswitch . "external_ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock"

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
            if [ -S /var/run/ovn/ovnnb_db.sock ];
            then
              break
            fi
            sleep 10
          done
          ${pkgs.coreutils}/bin/echo "OVN Northbound database socket is available."

          # Wait for OVN Southbound database socket to be available
          for i in {1..30}; do
            ${pkgs.coreutils}/bin/echo "Waiting for OVN Southbound database socket to be available..."
            if [ -S /var/run/ovn/ovnsb_db.sock ];
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
            # Requires OVN/OVS
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
        })
      ];

      #########################################################
      # Incus Preseed Service Override
      #########################################################
      incus-preseed = lib.mkMerge [
        (lib.mkIf (config.virtualisation.incus.preseed != null) {

          description = lib.mkForce "Incus initialization with preseed file (customised)";

          after = lib.mkAfter [
            # Requires OVN/OVS
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
      ]
      ++ lib.optionals ovnJoined [
        ovnConfig.northbound.port # OVN NB DB (Northbound)
        ovnConfig.southbound.port # OVN SB DB (Southbound)
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
