{pkgs, ...}: {
  imports = [];

  programs = {
    gnome-disks.enable = true;
    seahorse.enable = true;
  };

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
      extraWingpanelIndicators = with pkgs; [
        monitor
        wingpanel-indicator-ayatana
      ];

      # https://nixos.org/manual/nixos/stable/options.html#opt-services.xserver.desktopManager.pantheon.extraSwitchboardPlugs
      extraSwitchboardPlugs = [];
    };
  };

  services.pantheon = {
    apps.enable = true;
    contractor.enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      appeditor
      celluloid
      formatter
      gthumb
      simple-scan
      indicator-application-gtk3
      pantheon.sideload
      pantheon-tweaks
      yaru-theme
    ];

    pathsToLink = [
      "/libexec"
    ];

    pantheon.excludePackages = with pkgs.pantheon; [
      elementary-mail
      elementary-music
      elementary-photos
      elementary-videos
      epiphany
    ];
  };

  systemd.user.services.indicatorapp = {
    description = "indicator-application-gtk3";
    wantedBy = [
      "graphical-session.target"
    ];
    partOf = [
      "graphical-session.target"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.indicator-application-gtk3}/libexec/indicator-application/indicator-application-service";
    };
  };
}
