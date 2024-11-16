{
  networking = {
    hostName = "NUC";
    hostId = "def10001";
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
    ../../system/config/hardware/laptop
    ../../system/config/network/wireless
    ../../system/config/power
    ../../system/config/printing
    ../../system/config/services
    ../../system/config/services/throttled
    ../../system/config/services/upower
    ../../system/config/theme/catppuccin
    ../../system/config/video/intel

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # VMware virtualisation and Docker Container Host.
    ../../system/config/virtualisation/docker
    ../../system/config/virtualisation/host/vmware
  ];
}
