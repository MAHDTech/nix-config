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

    # NOTE: this host previously unset VK_ICD_FILENAMES on the hypridle and
    # swaync user services to dodge panvk Vulkan driver crashes on startup.
    # Both services are gone with Hyprland, so those overrides were dead and
    # have been removed rather than blindly re-pointed.
    #
    # If panvk crashes reappear under COSMIC, re-apply the same mitigation to
    # whichever COSMIC unit actually crashes (check `systemctl --user --failed`;
    # cosmic-osd.service and cosmic-settings-daemon.service are real units,
    # whereas cosmic-idle and cosmic-notifications are spawned by cosmic-session
    # and would need the variable set session-wide instead).
    #
    # TODO: Revisit once the kernel repeated mapping support (e.g. Adrián Larumbe's
    # "Support repeated mappings in GPUVM and Panthor" patch series, introducing OP_MAP_REPEAT)
    # is merged upstream and our kernel/Mesa is updated.
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

    # NOTE: DisplayLink USB dock (system/config/video/displaylink) is x86_64-only.
    # The Linux DisplayLink driver does not support aarch64.

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
    ../../system/config/desktop-environment/cosmic.nix

    # Login Manager
    ../../system/config/desktop-environment/greetd.nix

    # Theme
    ../../system/config/theme/stylix

    # Form Factor: Desktop
    ../../system/config/hardware/desktop

    # Networking (Wired only -- see hardware-configuration.nix for why the
    # shared wireless module is deliberately not imported here.)
    ../../system/config/network/hosts.nix

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
    # Render on the panthor GPU; cosmic-comp still scans out on the separate
    # display controller. The value is resolved against /dev/dri, so it must be
    # a bare name rather than an absolute path.
    COSMIC_RENDER_DEVICE = "cix-gpu";

    # NOTE: the previous AQ_NO_MODIFIERS / WLR_DRM_NO_MODIFIERS settings have no
    # cosmic-comp equivalent and have been dropped rather than guessed at. If
    # this board shows scanout corruption or blank outputs under COSMIC, the
    # analogous escape hatches are COSMIC_DISABLE_DIRECT_SCANOUT=1 and
    # COSMIC_DISABLE_OVERLAY_SCANOUT=1 — both cost performance, so only set them
    # if a real problem shows up.
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
