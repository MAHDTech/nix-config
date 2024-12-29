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

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

    # VMware virtualisation and Docker Container Host.
    ../../system/config/virtualisation/docker
    ../../system/config/virtualisation/host/vmware

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/intel.nix

    # GPU specific configuration.
    ../../system/config/video/intel
  ];
}
