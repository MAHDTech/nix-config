# ==========================================================================
#  JONS — Disko Configuration (BTRFS RAID 0)
#  AMD Ryzen Desktop with Intel ARC B580 GPU
#
#  BTRFS RAID 0 (stripe) across 2× Corsair MP600 PRO NVMe drives.
#  ESP is on NVMe 0 (no USB boot dependency).
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
      # NVMe Drive 1: ESP + BTRFS RAID 0 member
      # ================================================================
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB4273059HX";
        content = {
          type = "gpt";
          partitions = {
            # ESP partition
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

            # BTRFS RAID 0 — primary member
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "--data"
                  "raid0"
                  "--metadata"
                  "raid1"
                  "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB427305AF2-part1"
                ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/var" = {
                    mountpoint = "/var";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/var/lib" = {
                    mountpoint = "/var/lib";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/var/lib/docker" = {
                    mountpoint = "/var/lib/docker";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/var/lib/containers" = {
                    mountpoint = "/var/lib/containers";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/tmp" = {
                    mountpoint = "/tmp";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                };
              };
            };
          };
        };
      };

      # ================================================================
      # NVMe Drive 2: BTRFS RAID 0 member (entire disk)
      #
      # This partition is consumed by mkfs.btrfs on nvme0 via extraArgs.
      # Disko partitions it; the RAID 0 mkfs stripes both devices.
      # ================================================================
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_PRO_NH_A5JVB427305AF2";
        content = {
          type = "gpt";
          partitions = { };
        };
      };
    };
  };
}
