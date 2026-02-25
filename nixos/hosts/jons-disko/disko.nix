# ==========================================================================
#  JONS — Disko Configuration
#  AMD Ryzen Desktop with Intel ARC B580 GPU
#
#  MIGRATION NOTES:
#  This replaces the old hardware-configuration.nix fileSystems block.
#  The old layout used a Samsung USB Flash Drive for ESP + NixOS config.
#  The new layout puts ESP on the first NVMe (simpler, no USB dependency).
#
#  ZFS pool layout is preserved exactly as-is:
#    zpool (stripe) across 2× Corsair MP600 PRO NVMe
#
#  To install with this config:
#    sudo nix run github:nix-community/disko -- --mode disko ./disko.nix
#
#  WARNING: This will WIPE both NVMe drives. Backup first!
# ==========================================================================
_: {
  disko.devices = {
    disk = {
      # ================================================================
      # NVMe Drive 1: OS + ZFS data
      # ================================================================
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB4273059HX";
        content = {
          type = "gpt";
          partitions = {
            # ESP partition (was on USB, now on NVMe)
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0077"
                ];
              };
            };

            # Remaining space goes to ZFS
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zpool";
              };
            };
          };
        };
      };

      # ================================================================
      # NVMe Drive 2: ZFS data only (entire disk)
      # ================================================================
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB427305AF2";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zpool";
              };
            };
          };
        };
      };
    };

    # ==================================================================
    # ZFS Pool: zpool (stripe across 2 NVMe)
    # ==================================================================
    zpool = {
      zpool = {
        type = "zpool";
        mode = ""; # stripe (no redundancy, max performance — same as current)

        options = {
          ashift = "12";
          autotrim = "on";
        };

        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          "com.sun:auto-snapshot" = "false";
        };

        datasets = {
          # Root filesystem
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };

          # Boot (kernels, initrd — NOT ESP)
          boot = {
            type = "zfs_fs";
            mountpoint = "/boot/nixos";
            options.mountpoint = "legacy";
          };

          # Home directories
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };

          # Nix store
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              atime = "off";
            };
          };

          # Var
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options.mountpoint = "legacy";
          };

          # Var/lib
          "var/lib" = {
            type = "zfs_fs";
            mountpoint = "/var/lib";
            options.mountpoint = "legacy";
          };

          # Docker storage
          "var/lib/docker" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/docker";
            options.mountpoint = "legacy";
          };

          # Container storage
          "var/lib/containers" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/containers";
            options.mountpoint = "legacy";
          };

          # Tmp (ephemeral)
          tmp = {
            type = "zfs_fs";
            mountpoint = "/tmp";
            options = {
              mountpoint = "legacy";
              sync = "disabled";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };
  };
}
