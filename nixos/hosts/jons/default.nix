{
  lib,
  ...
}:
{
  networking = {
    hostName = "JONS";
    hostId = "def10002";
    nat.externalInterface = lib.mkForce "enp12s0";
  };

  # Created with: zfs create -o mountpoint=/var/lib/nix-build
  #   -o utf8only=off -o normalization=none -o atime=off zpool/nix-build
  fileSystems."/var/lib/nix-build" = {
    device = "zpool/nix-build";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  # Package tests may create filenames that are not valid UTF-8.
  nix.settings.build-dir = "/var/lib/nix-build";
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/var/lib/nix-build" ];

  # Override docker storage driver for ZFS (this host still uses ZFS)
  virtualisation.docker.storageDriver = "zfs";

  # GitHub Actions runner, registered at the enterprise level. The PAT
  # comes from 1Password via opnix (op://fleet/GitHub Runner/credential).
  services.github-runner-fleet = {
    enable = false;
    runners.enterprise = {
      url = "https://github.com/enterprises/MAHDTech";
      runnerGroup = "tars-cloud";
    };
  };

  environment.variables = {
    # Set AMD GPU as default for display/decoding; games can override with DRI_PRIME=1.
    # Must be set explicitly here: video/amd and video/intel each mkDefault this
    # to a different value, so the host has to break the tie.
    #
    # Decode deliberately stays on the AMD APU rather than being offloaded to the
    # Arc B580 — the Arc's 12GB is reserved for LLM inference and gaming, and
    # routing browser video through it would pin VRAM and keep xe resident.
    # Trade-off: Cezanne exposes no VP9/AV1 decode (H.264/HEVC/MPEG2/VC1/JPEG
    # only), so VP9 and AV1 streams still decode on the CPU. See the note on
    # forcing H.264 in browsers if YouTube remains heavy.
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  environment.sessionVariables = {
    # Use the AMD APU as the primary display renderer, offloading to Intel Arc B580.
    # cosmic-comp resolves a bare value against /dev/dri (see determine_primary_gpu
    # / try_parse_dev_from_str in cosmic-comp), so this must NOT be an absolute
    # path. The udev symlink below gives us a stable name to point at.
    COSMIC_RENDER_DEVICE = "amd-gpu";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:0e:00.0", SYMLINK+="dri/amd-gpu"
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:03:00.0", SYMLINK+="dri/intel-gpu"

    # Keep card1 (Arc B580) in logind's seat while the Smart TV is connected to
    # card1-HDMI-A-3 (the motherboard only has a single HDMI port, used by the
    # HP Z43 on card2-HDMI-A-5). Battlemage runtime PM is disabled via xe.runpm=0
    # in video/intel to prevent HDMI hotplug flap leaks across GPUs.
    # Only uncomment if no display is attached to the Arc B580:
    # SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:03:00.0", TAG-="seat", TAG-="master-of-seat", ENV{ID_SEAT}=""
  '';

  imports = [
    # Load hardware specific configuration.
    ./hardware

    # ACPI Daemon
    ../../system/config/services/acpid

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/amd
    ../../system/config/video/intel

    # Enable DisplayLink USB dock support (EVDI + dlm service)
    #../../system/config/video/displaylink

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

    # Theme
    ../../system/config/theme/stylix

    # Desktop
    ../../system/config/hardware/desktop
    ../../system/config/network/wireless
    ../../system/config/services/upower

    # Networking
    ../../system/config/network/hosts.nix

    # Desktop Environment
    ../../system/config/desktop-environment/cosmic.nix

    # Login Manager
    ../../system/config/desktop-environment/greetd.nix

    # Tailscale
    ../../system/config/services/tailscale

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/clamav-notify
    ../../system/config/services/trezor

    # VMware virtualisation and Docker Container Host.
    ../../system/config/virtualisation/docker
    #../../system/config/virtualisation/host/vmware

    # QEMU/KVM Virtualisation
    ../../system/config/virtualisation/host/qemu

    # Games
    ../../system/config/games

    # JONS-only: Beyond All Reason launcher pinned to the Arc B580.
    ./beyond-all-reason-arc.nix

    # Virtual Desktop
    ../../system/config/services/wayvnc

    # Netconsole Receiver for remote kernel boot logs
    ../../system/config/debug/netconsole/server.nix
  ];

  # Netconsole Receiver for remote kernel boot logs
  debug.netconsole.server = {
    enable = true;
    port = 6666;
    logFile = "/var/log/netconsole.log";
  };

  # Prevent automatic unattended reboots on JONS; stage boot generation instead.
  system.autoUpgrade.allowReboot = false;
}
