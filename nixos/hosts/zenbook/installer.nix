{
  ...
}:
{
  imports = [
    # Hardware specific config
    ./hardware

    # Generic installer base
    ../../system/installer/base.nix
    ../../system/installer/raw-efi-image.nix
  ];

  networking.hostName = "installer-zenbook";
  networking.hostId = "def00003";

  # Enable SSH inside the installer for NixOS Anywhere
  services.openssh.enable = true;

  # Disable emergency mode to prevent sulogin console locking on boot timeouts
  systemd.enableEmergencyMode = false;

  # Use systemd-based initrd for proper ARM64 hardware initialization
  boot.initrd.systemd = {
    enable = true;
    emergencyAccess = true;
  };
}
