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
    ./hardware

    # Power management and optimizations
    ./power.nix

    # CIX P1 HDMI/DP audio stub (driver pending upstream in cix-linux-main)
    ./audio.nix

    # CPU and Virtualisation
    ../../system/config/virtualisation/cpu/cix.nix
    ../../system/config/virtualisation/host/qemu

    # GPU specific configuration.
    ../../system/config/video/mali

    # Load system standard-operating-environment.
    ../../system/soe

    # System configuration
    ../../system/config/audio
    ../../system/config/bluetooth
    ../../system/config/fonts
    ../../system/config/power
    ../../system/config/printing
    ../../system/config/services

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # Theme
    ../../system/config/theme/stylix

    # Form Factor: Desktop
    ../../system/config/hardware/desktop

    # Networking (Wired and Wireless)
    ../../system/config/network/hosts.nix
    ../../system/config/network/wireless

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

  ];

  environment.sessionVariables = {
    AQ_DRM_DEVICES = lib.mkForce "/dev/dri/cix-display:/dev/dri/cix-gpu";
    WLR_DRM_DEVICES = lib.mkForce "/dev/dri/cix-display:/dev/dri/cix-gpu";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="CIXH5010:03", SYMLINK+="dri/cix-display"
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="CIXH5000:00", SYMLINK+="dri/cix-gpu"
  '';
}
