{
  ...
}:
{
  imports = [
    # Hardware specific config
    ./hardware-configuration.nix
    ./pd-mapper.nix

    # Generic installer base
    ../../system/installer/base.nix
    ../../system/installer/raw-efi-image.nix
  ];

  networking.hostName = "installer-zenbook";
  networking.hostId = "def00003";

  # Ensure the installer is as minimal as possible but has what we need
  services.openssh.enable = true;

  # Disable emergency mode to prevent sulogin console locking on boot timeouts
  systemd.enableEmergencyMode = false;
}
