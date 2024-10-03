{
  imports = [];

  # NOTE: cosmic packages now pulled from nixos-cosmic flake.

  hardware.system76.enableAll = true;

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Because we use system76-power
  services.power-profiles-daemon.enable = false;

  boot.extraModulePackages = with config.boot.kernelPackages; [
    system76-scheduler
    system76-power
  ];
}
