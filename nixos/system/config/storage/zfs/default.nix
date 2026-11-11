{
  config,
  lib,
  pkgs,
  ...
}:
let
  zfsPoolNames = [
    "zpool"
  ];

  zfsUserPackage = pkgs.zfs;
  baseZfsKernelModule = config.boot.kernelPackages.${zfsUserPackage.kernelModuleAttribute};
  kernelMajorMinor = lib.versions.majorMinor config.boot.kernelPackages.kernel.version;

  # Backport upstream OpenZFS Linux 7.3 compatibility (openzfs/zfs#19082,
  # openzfs/zfs#19553, NixOS/nixpkgs#579666) while nixpkgs zfs 2.4.4 still
  # declares kernelMaxSupportedMajorMinor = "7.2". Automatically becomes a
  # no-op once nixpkgs marks the module compatible with 7.3.
  zfsKernelModule =
    if
      baseZfsKernelModule.meta.broken && zfsUserPackage.version == "2.4.4" && kernelMajorMinor == "7.3"
    then
      baseZfsKernelModule.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.fetchpatch2 {
            url = "https://github.com/openzfs/zfs/commit/d966f3dd8c2e4eb04e52227b7a87f5828924f89c.patch?full_index=1";
            hash = "sha256-Oe0JPnMaDrh0tO2x+yJZ90kAba/MUnHgLNK02/uMaw4=";
          })
          (pkgs.fetchpatch2 {
            url = "https://github.com/openzfs/zfs/commit/cd3699d308e1b37dcdd0d5a9a8c3624deb5fc3e9.patch?full_index=1";
            hash = "sha256-3uqkN0KxcZ1SGI7eBOIvglGy5MxZJgXQO3vUPwcv2co=";
            excludes = [
              "include/os/linux/Makefile.am"
              "module/os/linux/spl/spl-taskq.c"
            ];
          })
          (pkgs.fetchpatch2 {
            url = "https://github.com/openzfs/zfs/commit/a128b8a075b5b13c737e56914cd7043bd3e9ebf8.patch?full_index=1";
            hash = "sha256-59/TKa+bPAgAfAH9mzJ51npjqO70nBlaEWerMHJcFuM=";
          })
          (pkgs.fetchpatch2 {
            url = "https://github.com/openzfs/zfs/commit/315bc75afc18f548df3b738b69bfaad7cff094ad.patch?full_index=1";
            hash = "sha256-c/cb6QxdggzeHJx4mggQYc5pshRADMxcZ1hg39JJezQ=";
            excludes = [ "include/os/linux/kernel/linux/simd_x86.h" ];
          })
          ./linux-7.3.patch
        ];
        postPatch = builtins.replaceStrings [ "7\\.2" "7.2" ] [ "7\\.3" "7.3" ] old.postPatch;
        meta = old.meta // {
          broken = false;
        };
      })
    else
      baseZfsKernelModule;
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

      package = zfsUserPackage;
      modulePackage = zfsKernelModule;
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
