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

  # Use systemd-based initrd for proper ARM64 hardware initialization
  boot.initrd.systemd = {
    enable = true;
    emergencyAccess = true;
  };

  systemd = {
    # Disable emergency mode to prevent sulogin console locking on boot timeouts
    enableEmergencyMode = false;

    # Disable nix-channel-init service since the raw image closure doesn't pre-pack nixos channel sources
    services = {
      nix-channel-init.enable = false;
    };
  };
}
