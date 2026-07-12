{
  pkgs,
  ...
}:
{
  imports = [ ];

  # Enable the System76 scheduler for performance optimization
  services.system76-scheduler.enable = true;

  environment.systemPackages = with pkgs; [
    # Core Desktop & Daemons
    cosmic-comp
    cosmic-bg
    cosmic-session
    cosmic-settings
    cosmic-settings-daemon
    cosmic-osd
    cosmic-notifications
    cosmic-idle
    cosmic-greeter
    cosmic-workspaces-epoch
    xdg-desktop-portal-cosmic

    # Desktop Shell Components
    cosmic-panel
    cosmic-launcher
    cosmic-applibrary
    cosmic-applets
    cosmic-icons
    cosmic-wallpapers

    # Core Applications
    cosmic-term
    cosmic-files
    cosmic-edit
    cosmic-store
    cosmic-player
    cosmic-screenshot
    cosmic-reader
    tasks
    cosmic-monitor

    # Extensions & Utilities
    cosmic-ext-calculator
    cosmic-ext-ctl
    cosmic-ext-tweaks
    cosmic-ext-applet-caffeine
    cosmic-ext-applet-external-monitor-brightness
    cosmic-ext-applet-minimon
    cosmic-ext-applet-privacy-indicator
    cosmic-ext-applet-sysinfo
    cosmic-ext-applet-weather
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    COSMIC_DATA_CONTROL_ENABLED = "1"; # Bypasses Wayland clipboard restriction for managers/macros
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

    displayManager.cosmic-greeter.enable = false;
  };

}
