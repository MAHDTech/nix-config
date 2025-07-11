{
  networking = {
    hostName = "NUC";
    hostId = "def10001";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/intel.nix

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

    # Storage
    ../../system/config/storage/zfs
    #../../system/config/storage/persistence

    # Theme
    ../../system/config/theme/catppuccin

    # Laptop
    ../../system/config/hardware/laptop
    ../../system/config/network/wireless
    ../../system/config/services/throttled
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

    # Virtualisation
    #../../system/config/virtualisation/docker
    #../../system/config/virtualisation/host/vmware
    #../../system/config/virtualisation/incus
  ];
}
