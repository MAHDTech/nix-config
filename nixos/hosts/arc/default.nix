# ==========================================================================
#  ARC — AMD Ryzen Desktop with Intel ARC B580 GPU
#
#  Disko-based host with BTRFS RAID 0 across 2× NVMe.
#
#  Changes from original JONS host:
#    - Replaced hardware-configuration.nix with disko.nix (BTRFS subvolumes)
#    - ESP moved from USB drive to NVMe (no USB boot dependency)
#    - Bootloader changed from GRUB to systemd-boot (UEFI native)
#    - Removed ZFS (root filesystem is now BTRFS)
# ==========================================================================
{
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/intel

    # Load system standard-operating-environment.
    ../../system/soe

    # System configuration
    ../../system/config/audio
    ../../system/config/bluetooth
    ../../system/config/disk/gparted
    ../../system/config/fonts
    ../../system/config/power
    ../../system/config/printing
    ../../system/config/services

    # Theme
    ../../system/config/theme/catppuccin

    # Desktop
    ../../system/config/hardware/desktop
    ../../system/config/network/wireless
    ../../system/config/services/upower

    # Networking
    ../../system/config/network/hosts.nix

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # Tailscale
    ../../system/config/services/tailscale

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

    # VMware virtualisation and Docker Container Host.
    ../../system/config/virtualisation/docker

    # QEMU/KVM Virtualisation
    ../../system/config/virtualisation/host/qemu

    # Games
    ../../system/config/games

    # Virtual Desktop
    ../../system/config/services/wayvnc
  ];

  networking = {
    hostName = "ARC";
    hostId = "653850a3";

    useDHCP = lib.mkDefault false;
    interfaces = {
      enp10s0 = {
        useDHCP = false;
        mtu = lib.mkForce 9000;
      };
      br0 = {
        useDHCP = true;
        mtu = 9000;
      };
    };
    bridges = {
      br0 = {
        interfaces = [ "enp10s0" ];
      };
    };
  };

  swapDevices = [ ];
}
