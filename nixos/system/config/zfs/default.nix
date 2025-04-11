{pkgs, ...}: let
  zfsPoolNames = [
    "bpool",
    "zpool",
  ];
in {
  boot = {
    zfs = {
      requestEncryptionCredentials = true;

      package = pkgs.zfs;

      extraPools = zfsPoolNames;

      devNodes = "/dev/disk/by-partuuid";

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
}
