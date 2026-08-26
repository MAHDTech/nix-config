{
  pkgs,
  ...
}:
let
  zfsPoolNames = [
    "zpool"
  ];
in
{
  boot = {
    kernelParams = [
      "zfs.zfs_arc_max=12884901888"

      # arc_dnode_limit derives from 10% of arc_max by default, which the
      # 12 GiB cap above shrinks to ~1.2 GB - well under this pool's ~2.1 GB
      # dnode working set. arc_prune then spins permanently trying to evict
      # pinned inodes it can never free. 50% gives a 6 GiB dnode budget
      # without growing total ARC.
      "zfs.zfs_arc_dnode_limit_percent=50"
    ];
    zfs = {
      requestEncryptionCredentials = true;

      package = pkgs.zfs;
      #package = pkgs.zfs_unstable; # Experimental

      # ZFS auto-import pools.
      extraPools = zfsPoolNames;

      devNodes = "/dev/disk/by-partuuid";

      unsafeAllowHibernation = false;
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
      enable = false;

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
