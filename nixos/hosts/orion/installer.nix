{
  ...
}:
{
  imports = [
    # Hardware specific config
    ./hardware-configuration.nix

    # Generic installer base
    ../../system/installer/base.nix
    ../../system/installer/raw-efi-image.nix
  ];

  networking.hostName = "installer-orion";
  networking.hostId = "def00004";
}
