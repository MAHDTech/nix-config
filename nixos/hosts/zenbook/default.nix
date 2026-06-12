{ ... }:
{

  networking = {
    hostName = "ZENBOOK";
    hostId = "def00003";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware

    # Power management and optimizations
    ./power.nix

    # Remote crash capture via netconsole (loads after network is up)
    ./netconsole.nix

    # CPU and Virtualisation
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
}
