{ pkgs, ... }:
let
  zfsPoolNames = [
    "zpool"
  ];
in
{
  boot = {
    zfs = {
      requestEncryptionCredentials = true;

      package = pkgs.zfs;
      #package = pkgs.zfs_unstable; # Experimental

      # ZFS auto-import pools.
      extraPools = zfsPoolNames;

      devNodes = "/dev/disk/by-partuuid";

      forceImportRoot = true;
      forceImportAll = true;

      allowHibernation = false;
    };
  };

  services = {
    zfs = {
      autoScrub = {
        enable = true;
        pools = zfsPoolNames;
      };
    };

    # Sanoid for automated ZFS snapshots and replication
    sanoid = {
      enable = true;

      settings = {
        # Global template for snapshot policies
        template_default = {
          frequently = 0;
          hourly = 24;
          daily = 7;
          monthly = 12;
          yearly = 1;
          autosnap = "yes";
          autoprune = "yes";
        };

        # Template for shared storage with more frequent snapshots
        template_shared = {
          frequently = 4; # Every 15 minutes
          hourly = 24;
          daily = 7;
          monthly = 12;
          yearly = 1;
          autosnap = "yes";
          autoprune = "yes";
        };

        # Shared storage dataset configuration
        "zpool/shared-storage" = {
          use_template = "template_shared";
          recursive = "yes";
        };
      };
    };
  };

  systemd = {
    services = {
      zfs-mount = {
        # Disable the zfs-mount service (for native ZFS mounts)
        # Enable the zfs-mount service (for legacy ZFS mounts)
        enable = true;
      };
    };
  };

}
