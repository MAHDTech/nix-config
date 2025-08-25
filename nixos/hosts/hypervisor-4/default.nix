{
  ...
}:
{
  networking = {
    hostName = "HYPERVISOR-4";
    hostId = "def90004";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/amd

    # Storage specific configuration.
    ../../system/config/storage/zfs

    # Theme specific configuration.
    ../../system/config/theme/catppuccin

    # Network specific configuration.
    ./network.nix

    # LINSTOR
    ./linstor.nix

    # Incus
    ./incus.nix

    # AppArmor
    ../../system/config/security/apparmor
  ];
}
