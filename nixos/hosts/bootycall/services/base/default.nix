{ lib, pkgs, ... }:
{
  # Time and Locale configuration
  time.timeZone = "Australia/Canberra";
  i18n.defaultLocale = "en_AU.UTF-8";

  # Nix daemon settings
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Enable SSH service
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Fixed user account: cooper (No Home Manager)
  users.users.cooper = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "users"
    ];
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvQpgd14xx/ZZeIFzoa2ztmk0MNjHObmIbbnkxzCSvV mahdtech@local"
    ];
  };

  # Also add the same SSH keys to root for convenience
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvQpgd14xx/ZZeIFzoa2ztmk0MNjHObmIbbnkxzCSvV mahdtech@local"
  ];

  # Slim down standard packages (Only critical tools)
  environment.systemPackages = with pkgs; [
    curl
    git
    vim
    tcpdump
  ];

  # Ensure Flatpak or Portals are disabled/satisfied if imported from default modules
  xdg.portal.enable = lib.mkForce false;
}
