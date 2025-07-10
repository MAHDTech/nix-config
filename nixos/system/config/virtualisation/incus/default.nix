{
  hostConfig ? { },
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let

  #########################
  # Default configuration
  #########################
  defaultConfig = {
    preseed = {
      cluster = null;
      config = {
        #"core.https_address" = ":8443";
        "images.auto_update_interval" = 6;
      };
      storage_pools = [
        # Default storage pool.
        {
          name = "default";
          driver = "zfs";
          config = {
            "source.wipe" = false;
            "zfs.clone_copy" = true;
            "zfs.export" = true;
            source = "zpool/var/lib/incus/storage-pools/default";
          };
        }
        # Storage pool for instances.
        {
          name = "instances";
          driver = "zfs";
          config = {
            "source.wipe" = false;
            "zfs.clone_copy" = true;
            "zfs.export" = true;
            source = "zpool/var/lib/incus/storage-pools/instances";
          };
        }
        # Storage pool for ISO images.
        {
          name = "iso";
          driver = "zfs";
          config = {
            "source.wipe" = false;
            "zfs.clone_copy" = true;
            "zfs.export" = true;
            source = "zpool/var/lib/incus/storage-pools/iso";
          };
        }
      ];
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "192.168.1.1/24";
            "ipv6.address" = "none";
          };
        }
        #{
        #  name = "platform";
        #  type = "physical";
        #  config = {
        #    "ipv4.address" = "dhcp";
        #    "ipv6.address" = "none";
        #    "dns.nameservers" = [
        #      "10.10.200.254"
        #    ];
        #    "mtu" = 1500;
        #    "gvrp" = false;
        #    "vlan" = 200;
        #}
      ];
      profiles = [
        # Default profile.
        {
          name = "default";
          description = "Default profile";
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
              network = "incusbr0";
              type = "nic";
            };
          };
        }
        # System Containers
        {
          name = "system-containers";
          description = "System Containers profile";
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
              network = "incusbr0";
              type = "nic";
            };
          };
        }
        # Application Containers
        {
          name = "application-containers";
          description = "Application Containers profile";
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
              network = "incusbr0";
              type = "nic";
            };
          };
        }
        # Virtual Machines
        {
          name = "virtual-machines";
          description = "Virtual Machines profile";
          config = {
            "limits.cpu" = 4;
            "limits.memory" = "4GiB";
            "security.nesting" = true;
            "security.secureboot" = false;
            "security.syscalls.intercept.mknod" = true;
            "security.syscalls.intercept.setxattr" = true;
            "security.syscalls.intercept.sysinfo" = true;
          };
          devices = {
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
          };
        }
      ];
      storage_volumes = [ ];
    };
  };

  #########################
  # Validate cluster configuration
  #########################
  validateCluster =
    config:
    if config.preseed.cluster != null && config.preseed.cluster.server_name == null then
      throw "Cluster is enabled but server_name is not specified"
    else
      config;

  #########################
  # Merge host config with defaults.
  #########################
  mergedConfig = lib.recursiveUpdate defaultConfig hostConfig;

  #########################
  # Validate the merged configuration
  #########################
  validatedConfig = validateCluster mergedConfig;
in
{

  #########################
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
  #########################

  imports = [ ];

  environment.systemPackages = with pkgs; [
  ];

  virtualisation = {
    incus = {
      enable = true;

      startTimeout = 600;
      socketActivation = false;
      softDaemonRestart = true;

      agent = {
        enable = false;
      };

      ui = {
        enable = true;
      };

      preseed = {
        inherit (validatedConfig.preseed)
          cluster
          config
          storage_pools
          storage_volumes
          networks
          profiles
          ;
      };
    };
  };

  networking = {
    nftables = {
      enable = true;
    };
    firewall = {
      trustedInterfaces = [
        "incusbr0"
      ];
    };
  };
}
