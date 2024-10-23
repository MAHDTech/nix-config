{
  config,
  pkgs,
  ...
}: {
  imports = [];

  # NOTE: cosmic packages now pulled from nixos-cosmic flake.

  environment.systemPackages = with pkgs; [
    #system76-firmware
  ];

  hardware.system76 = {
    enableAll = false;
    power-daemon.enable = false;
    kernel-modules.enable = false;
    firmware-daemon.enable = false;
  };

  services = {
    # COSMIC Desktop
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;

    # Other
    system76-scheduler.enable = false;
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [
    # If using the System76 scheduler
    #system76-scheduler

    # Disable when using power-profiles daemon or TLP
    #system76-power
  ];
}
