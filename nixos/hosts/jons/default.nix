{
  lib,
  ...
}:
{
  networking = {
    hostName = "JONS";
    hostId = "def10002";
  };

  # Override docker storage driver for ZFS (this host still uses ZFS)
  virtualisation.docker.storageDriver = "zfs";

  environment.variables = {
    # Set AMD GPU as default for display/decoding; games can override with DRI_PRIME=1
    LIBVA_DRIVER_NAME = "amdgpu";
  };

  environment.sessionVariables = {
    # Force Hyprland to use AMD APU as primary display renderer, offloading to Intel Arc B580
    AQ_DRM_DEVICES = lib.mkForce "/dev/dri/by-path/pci-0000:0f:00.0-card:/dev/dri/by-path/pci-0000:03:00.0-card";
    WLR_DRM_DEVICES = lib.mkForce "/dev/dri/by-path/pci-0000:0f:00.0-card:/dev/dri/by-path/pci-0000:03:00.0-card";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # ACPI Daemon
    ../../system/config/services/acpid

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/amd
    ../../system/config/video/intel

    # Enable DisplayLink USB dock support (EVDI + dlm service)
    ../../system/config/video/displaylink

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
    ../../system/config/desktop-environment/hyprland.nix

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
  ];
}
