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

  networking.hostName = "installer-orion";
  networking.hostId = "def00004";

  # Enable SSH inside the installer for NixOS Anywhere
  services.openssh.enable = true;

  # Allow emergency shell access in systemd initrd
  boot.initrd.systemd = {
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
