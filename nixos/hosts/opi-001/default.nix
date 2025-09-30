{
  pkgs,
  ...
}:
{

  # Module arguments.
  _module.args = {
    # For Orange PI 5 Pro, use the latest bleeding edge kernel.
    customKernelPackage = pkgs.linuxPackages_latest;
  };

  networking = {
    hostName = "OPI-001";
    hostId = "adf00001";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # Storage
    ../../system/config/storage/zfs

    # Theme
    ../../system/config/theme/catppuccin

    # Networking
    ../../system/config/network/hosts.nix

  ];
}
