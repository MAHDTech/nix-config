{
  ...
}:
{
  imports = [
    # Get hardware configuration from the main host
    ./hardware

    # Generic installer base
    ../../system/installer/base.nix
    ../../system/installer/raw-efi-image.nix
  ];

  networking.hostName = "installer-jons";
  networking.hostId = "def00001";
}
