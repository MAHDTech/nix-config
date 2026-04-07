{ ... }:
{

  networking = {
    hostName = "ZENBOOK";
    hostId = "def00003";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix
    ./pd-mapper.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/qcom.nix

    # GPU specific configuration.
    ../../system/config/video/qcom

    # Load system standard-operating-environment.
    ../../system/soe

    # Power management and optimizations
    ./power.nix

    # System configuration
    ../../system/config/audio
    ../../system/config/bluetooth
    #../../system/config/disk/gparted
    ../../system/config/fonts
    ../../system/config/power
    ../../system/config/printing
    #../../system/config/services

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
    #../../system/config/programs/1password
    #../../system/config/services/trezor

    # Games
    #../../system/config/games

  ];
}
