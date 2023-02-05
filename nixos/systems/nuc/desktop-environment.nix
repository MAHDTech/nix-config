{ config, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [

    wayland
    wayland-utils
    wayland-protocols

  ];

  services.xserver = {

    enable = true ;

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

  services.pantheon.apps.enable = true;

  environment.pantheon.excludePackages = [

    #"elementary-mail"
    #"pantheon.elementary-tasks"
    #"pantheon.elementary-music"
    #"pantheon.elementary-videos"
    #"pantheon.elementary-photos"
    #"pantheon.elementary-camera"
    #"pantheon.elementary-terminal"
    #"pantheon.elementary-calendar"
    #"pantheon.elementary-screenshot"
    #"pantheon.elementary-calculator"

  ];

}
