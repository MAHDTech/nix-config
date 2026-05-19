{ ... }:
{
  networking = {
    hostName = "ORION";
    hostId = "def00004";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # Power management and optimizations
    ./power.nix

    # System configuration
    ../../system/config/audio
    ../../system/config/bluetooth
    ../../system/config/fonts
    ../../system/config/power
    ../../system/config/printing

    # Theme
    ../../system/config/theme/catppuccin

    # Desktop Environment
    ../../system/config/hardware/desktop
    ../../system/config/network/wireless

    # Networking
    ../../system/config/network/hosts.nix

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix
  ];
}
