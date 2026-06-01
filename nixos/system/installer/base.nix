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
      # Inject the NixOS PATH into every SSH session (interactive and
      # non-interactive). nixos-anywhere runs systemd-detect-virt via a
      # non-interactive SSH command which skips /etc/profile and therefore
      # never gets /run/current-system/sw/bin on $PATH. Without it, systemd
      # binaries cannot find libsystemd-shared-*.so and nixos-anywhere aborts
      # at the "Gathering machine facts" phase.
      SetEnv = "PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
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
