{ lib, ... }:
{
  networking = {
    hostName = "ORION";
    hostId = "def00004";
  };

  # Disable hardware watchdog. The SBSA Generic Watchdog on this board
  # initializes with a 10s timeout, causing reboot loops before systemd can pet it.
  systemd = {
    settings.Manager = {
      RuntimeWatchdogSec = lib.mkForce "0";
      RebootWatchdogSec = lib.mkForce "0";
      KExecWatchdogSec = lib.mkForce "0";
    };
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
    ../../system/config/services

    # Theme
    ../../system/config/theme/catppuccin

    # Desktop Environment
    ../../system/config/hardware/desktop
    ../../system/config/network/wireless

    # Video / Graphics
    ../../system/config/video/mali

    # Networking
    ../../system/config/network/hosts.nix

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix
  ];
}
