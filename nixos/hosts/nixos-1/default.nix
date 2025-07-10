{
  networking = {
    hostName = "NIXOS-1";
    hostId = "def00001";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # System Configuration
    ../../system/config/fonts
    ../../system/config/storage/zfs

    # Headless

    # VMware virtualisation Guest.
    ../../system/config/virtualisation/guest/vmware
  ];
}
