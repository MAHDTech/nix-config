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

  # Prevent kernel from disabling the display panel regulator (VREG_EDP_3P3)
  # during late boot cleanup when the MSM GPU driver is blacklisted.
  boot.kernelParams = [
    "regulator_ignore_unused"
  ];

  systemd = {
    # Disable emergency mode to prevent sulogin console locking on boot timeouts
    enableEmergencyMode = false;

    services = {
      # Disable nix-channel-init service since the raw image
      # closure doesn't pre-pack nixos channel sources
      nix-channel-init.enable = false;

      # Disable qcom-remoteproc services inside installer context
      qcom-remoteproc-load.enable = false;
      qcom-remoteproc-start.enable = false;
      pd-mapper.enable = false;
    };
  };
}
