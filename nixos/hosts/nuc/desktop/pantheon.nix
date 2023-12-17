{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.xserver = {
    enable = true;

    updateDbusEnvironment = true;

    displayManager.lightdm = {
      enable = true;
      greeters.pantheon.enable = true;
    };

    desktopManager.pantheon = {
      enable = true;

      # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraWingpanelIndicators
      extraWingpanelIndicators = [];

      # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraSwitchboardPlugs
      extraSwitchboardPlugs = [];
    };
  };

  programs.pantheon-tweaks.enable = true;

  services.pantheon = {
    apps.enable = true;
    contractor.enable = true;
  };

  environment.pantheon.excludePackages = [
    #"pkgs.pantheon.elementary-camera"
  ];
}
