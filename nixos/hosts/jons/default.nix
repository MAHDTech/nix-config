{
  networking = {
    hostName = "JONS";
    hostId = "def10002";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

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
    ../../system/config/theme/catppuccin
    ../../system/config/video/nvidia

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # Tailscale
    ../../system/config/services/tailscale

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

    # VMware virtualisation and Docker Container Host.
    ../../system/config/virtualisation/docker
    ../../system/config/virtualisation/host/vmware

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix
  ];
}
