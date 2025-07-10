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
