{
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/installation-device.nix")
  ];

  # Basic Installer configuration for nixos-anywhere
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Known password for initial access
  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
  };

  # Tools useful for manual rescue or investigation
  environment.systemPackages = with pkgs; [
    git
    htop
    parted
    vim
    curl
    pciutils
    usbutils
  ];

  # Networking
  networking.useDHCP = lib.mkDefault true;
  networking.hostName = lib.mkDefault "nixos-installer";

  # Disable some installer-specific things that might interfere with a "Raw" boot
  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
  };

  system.stateVersion = "26.05";
}
