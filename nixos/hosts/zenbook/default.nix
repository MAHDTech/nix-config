{ lib, ... }:
{
  # Disable hardware watchdog to prevent system starvation resets under load
  systemd.settings.Manager = {
    RuntimeWatchdogSec = lib.mkForce "0";
    RebootWatchdogSec = lib.mkForce "0";
    KExecWatchdogSec = lib.mkForce "0";
  };

  networking = {
    hostName = "ZENBOOK";
    hostId = "def00003";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware

    # Power management and optimizations
    ./power.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/qcom.nix
    ../../system/config/virtualisation/host/qemu

    # GPU specific configuration.
    ../../system/config/video/qcom

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

    # Form Factor: Laptop
    ../../system/config/hardware/laptop

    # Networking (Wired and Wireless)
    ../../system/config/network/hosts.nix
    ../../system/config/network/wireless

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

    # Backup
    ../../system/config/disk/backup
  ];

  services.tars-backup = {
    enable = true;
    userName = "mahdtech";
    diskUuids = [ ];
  };

  environment.sessionVariables = {
    # Force Hyprland to use our stable udev symlink for rendering
    AQ_DRM_DEVICES = "/dev/dri/adreno-gpu";
    WLR_DRM_DEVICES = "/dev/dri/adreno-gpu";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="ae01000.display-controller", SYMLINK+="dri/adreno-gpu"
  '';
}
