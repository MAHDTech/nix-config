{
  config,
  pkgs,
  ...
}:
{
  imports = [ ];

  # NOTE: cosmic packages now pulled from nixos-cosmic flake.

  environment.systemPackages = with pkgs; [
    #system76-firmware

    # Cosmic apps
    cosmic-applets
    cosmic-bg
    cosmic-edit
    cosmic-ext-calculator
    cosmic-ext-ctl
    cosmic-files
    cosmic-icons
    cosmic-idle
    cosmic-launcher
    cosmic-osd
    cosmic-panel
    cosmic-player
    cosmic-randr
    cosmic-screenshot
    cosmic-session
    cosmic-settings
    cosmic-settings-daemon
    cosmic-store
    cosmic-term
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    COSMIC_DATA_CONTROL_ENABLED = "1";
  };

  hardware.system76 = {
    enableAll = false;
    power-daemon.enable = false;
    kernel-modules.enable = false;
    firmware-daemon.enable = false;
  };

  services = {

    # COSMIC Desktop
    desktopManager.cosmic = {
      enable = true;
      xwayland = {
        enable = true;
      };
    };

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

  systemd = {
    packages = with pkgs; [
      observatory
    ];
    services = {
      monitord = {
        wantedBy = [
          "multi-user.target"
        ];
      };
    };
  };
}
