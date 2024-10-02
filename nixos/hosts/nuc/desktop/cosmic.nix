{
  imports = [];

  # NOTE: cosmic packages now pulled from nixos-cosmic flake.

  hardware.system76.enableAll = true;

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
}
