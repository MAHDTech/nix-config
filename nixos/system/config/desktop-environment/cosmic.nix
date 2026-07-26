{
  pkgs,
  lib,
  ...
}:
{
  imports = [ ];

  # Enable the System76 scheduler for performance optimization
  services.system76-scheduler.enable = true;

  environment = {
    systemPackages =
      with pkgs;
      [
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
      ]
      # Clipboard manager applet. Custom package (not yet in nixpkgs) supplied
      # by overlays/default.nix. Gated to x86_64 for now: the aarch64 hosts
      # cross-compile, and a Rust + libcosmic + wgpu cross build is unproven.
      # Same conditional pattern as home/nix/packages/custom/default.nix.
      ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        cosmic-ext-applet-clipboard-manager
      ];

    sessionVariables = {
      NIXOS_OZONE_WL = "1";

      # Exposes the ext-data-control-v1 protocol, which clipboard managers
      # require. Without this COSMIC permits no clipboard history at all.
      COSMIC_DATA_CONTROL_ENABLED = "1";

      # Fix 1Password desktop integration for authentication dialogue boxes.
      GTK_USE_PORTAL = "1";
    };

    variables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "gtk4";
    };
  };

  # NOTES:
  #   - services.desktopManager.cosmic already enables xdg.portal with
  #     xdg-desktop-portal-cosmic + xdg-desktop-portal-gtk, security.polkit,
  #     programs.dconf and services.libinput. Do not restate them here.
  #   - xdg-desktop-portal-cosmic ships cosmic-portals.conf, which already
  #     binds org.freedesktop.impl.portal.Secret to oo7-portal;gnome-keyring,
  #     so 1Password SSH prompts keep working without explicit portal config.
  xdg.portal.xdgOpenUsePortal = true;

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
