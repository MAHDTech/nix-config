{ inputs, config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  services.xserver = {

    enable = true ;

    updateDbusEnvironment = true;

    desktopManager.pantheon.enable = true;

    displayManager.lightdm = {

      enable = true;
      greeters.pantheon.enable = true;

    };

    # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraWingpanelIndicators
    desktopManager.pantheon.extraWingpanelIndicators = [

    ];

    # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraSwitchboardPlugs
    desktopManager.pantheon.extraSwitchboardPlugs = [

    ];

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
