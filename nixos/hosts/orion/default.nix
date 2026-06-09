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

    # Mitigate panvk Vulkan driver crashes on startup for Wayland services.
    # Force them to use OpenGL/GLES fallback by unsetting VK_ICD_FILENAMES.
    # TODO: Remove these overrides once the kernel repeated mapping support (e.g. Adrián Larumbe's
    # "Support repeated mappings in GPUVM and Panthor" patch series, introducing OP_MAP_REPEAT)
    # is merged upstream and our kernel/Mesa is updated.
    user.services = {
      hypridle.serviceConfig.Environment = [ "VK_ICD_FILENAMES=" ];
      swaync.serviceConfig.Environment = [ "VK_ICD_FILENAMES=" ];
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

    # Backup
    ../../system/config/disk/backup
  ];

  services.tars-backup = {
    enable = true;
    userName = "mahdtech";
    diskUuids = [ ];
  };

  environment.sessionVariables = {
    AQ_DRM_DEVICES = lib.mkForce "/dev/dri/cix-gpu:/dev/dri/cix-display";
    WLR_DRM_DEVICES = lib.mkForce "/dev/dri/cix-gpu:/dev/dri/cix-display";
    AQ_NO_MODIFIERS = "1";
    WLR_DRM_NO_MODIFIERS = "1";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="14160000.disp-controller", SYMLINK+="dri/cix-display"
    SUBSYSTEM=="drm", KERNEL=="card*", DRIVERS=="panthor", SYMLINK+="dri/cix-gpu"
  '';

  boot.postBootCommands = ''
    # Disable USB 3.0 Bus 14 root hub to prevent DisplayPort Alt Mode lane sharing mismatch warnings/log spam.
    # The udev ATTR{disable}="1" rule fails because the sysfs disable attribute does not exist on this kernel.
    # Unbinding the root hub device "usb14" from the usb driver stops the training loop completely.
    if [ -e /sys/bus/usb/drivers/usb/unbind ]; then
      echo "usb14" > /sys/bus/usb/drivers/usb/unbind
    fi
  '';
}
