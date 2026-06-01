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

  # Known password for initial access — both root and nixos accounts.
  # installation-device.nix sets nixos user with an empty password (console
  # auto-login) which blocks SSH password auth. Override both explicitly.
  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
  };
  users.users.nixos = {
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
