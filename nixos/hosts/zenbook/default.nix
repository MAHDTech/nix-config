{
  pkgs,
  ...
}:
{

  # Module arguments.
  _module.args = {
    # For Qualcomm Snapdragon X Elite, use the latest bleeding edge kernel.
    #customKernelPackage = pkgs.linuxPackages_latest;
    customKernelPackage = pkgs.linuxPackages_6_16;
  };

  networking = {
    hostName = "ZENBOOK";
    hostId = "def00003";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/qcom.nix

    # GPU specific configuration.
    #../../system/config/video/qcom

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

    # Storage
    ../../system/config/storage/zfs
    #../../system/config/storage/persistence

    # Theme
    ../../system/config/theme/catppuccin

    # Laptop
    ../../system/config/hardware/laptop
    ../../system/config/network/wireless
    ../../system/config/services/upower

    # CPU Throttling
    #../../system/config/services/thermald # there can only be one
    #../../system/config/services/throttled

    # Networking
    ../../system/config/network/hosts.nix

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # Tailscale
    #../../system/config/services/tailscale

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

    # Virtualisation
    #../../system/config/virtualisation/docker
    #../../system/config/virtualisation/host/vmware
    #../../system/config/virtualisation/incus

    # Games
    #../../system/config/games

  ];
}
