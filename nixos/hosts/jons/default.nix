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

  # Override docker storage driver for ZFS (this host still uses ZFS)
  virtualisation.docker.storageDriver = "zfs";

  environment.variables = {
    # Set AMD GPU as default for display/decoding; games can override with DRI_PRIME=1
    LIBVA_DRIVER_NAME = "amdgpu";
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
    ../../system/config/services/trezor

    # VMware virtualisation and Docker Container Host.
    ../../system/config/virtualisation/docker
    #../../system/config/virtualisation/host/vmware

    # QEMU/KVM Virtualisation
    ../../system/config/virtualisation/host/qemu

    # Games
    ../../system/config/games

    # Virtual Desktop
    ../../system/config/services/wayvnc

    # Netconsole Receiver for remote BootyCall boot logs
    ../../system/config/debug/netconsole/server.nix
  ];

  # Netconsole Receiver for remote kernel boot logs
  debug.netconsole.server = {
    enable = true;
    port = 6666;
    logFile = "/var/log/netconsole.log";
  };
}
