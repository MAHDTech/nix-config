{ config, pkgs, ... }:

{

  services.xserver = {

    enable = true ;

    desktopManager.pantheon.enable = true;

    displayManager.lightdm.greeters.pantheon.enable = true;
    displayManager.lightdm.enable = true;

    # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraWingpanelIndicators
    desktopManager.pantheon.extraWingpanelIndicators = [

    ];

    # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraSwitchboardPlugs
    desktopManager.pantheon.extraSwitchboardPlugs = [

    ];

  };

  services.pantheon.apps.enable = true;

}