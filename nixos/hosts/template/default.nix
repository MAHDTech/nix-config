{
  networking = {
    hostName = "TEMPLATE";
    hostId = "def00000";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # System Configuration
    ../../system/config/fonts
    ../../system/config/zfs
    ../../system/config/theme/catppuccin

    # Headless

    # VMware virtualisation Guest.
    ../../system/config/virtualisation/guest/vmware
  ];
}
