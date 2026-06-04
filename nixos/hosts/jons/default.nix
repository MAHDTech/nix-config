{
  pkgs,
  ...
}:
{
  networking = {
    hostName = "JONS";
    hostId = "def10002";

    # Allow netconsole UDP receiver from Zenbook
    firewall.allowedUDPPorts = [ 6666 ];
  };

  # Netconsole receiver: captures kernel messages from Zenbook crash events
  systemd.services.netconsole-receiver = {
    description = "Netconsole UDP receiver for Zenbook crash capture";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nmap}/bin/ncat --udp -l 6666 -k";
      StandardOutput = "append:/var/log/netconsole-zenbook.log";
      StandardError = "journal";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Override docker storage driver for ZFS (this host still uses ZFS)
  virtualisation.docker.storageDriver = "zfs";

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/intel

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
