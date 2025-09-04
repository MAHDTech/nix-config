{
  systemd.user = {
    startServices = true;

    services = {
      wallpaper-manager-daemon = {
        Unit = {
          Description = "Wallpaper Manager Daemon Service";
          PartOf = [ "hyprland-session.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "%h/.local/bin/wallpaper-manager-daemon";
          Restart = "on-failure";
          RestartSec = "10";
          StandardOutput = "journal";
          StandardError = "journal";

          # Environment variables for Wayland
          Environment = [
            "XDG_RUNTIME_DIR=%t"
            "DISPLAY=:0"
            "XDG_SESSION_TYPE=wayland"
            "HOME=%h"
            "USER=%U"
            "PATH=%h/.local/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
            "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
            "XDG_CURRENT_DESKTOP=Hyprland"
          ];

          # Working directory
          WorkingDirectory = "%h";

          # Kill mode to ensure clean shutdown
          KillMode = "mixed";
          KillSignal = "SIGTERM";
          TimeoutStopSec = "30";
        };

        Install = {
          WantedBy = [ "hyprland-session.target" ];
        };
      };

      wallpaper-manager = {
        Unit = {
          Description = "Wallpaper Manager Service";
          After = [ "wallpaper-manager-daemon.service" ];
          Requires = [ "wallpaper-manager-daemon.service" ];
          PartOf = [ "hyprland-session.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "%h/.local/bin/wallpaper-manager";
          Restart = "on-failure";
          RestartSec = "10";
          StandardOutput = "journal";
          StandardError = "journal";

          # Environment variables for Wayland
          Environment = [
            "XDG_RUNTIME_DIR=%t"
            "DISPLAY=:0"
            "XDG_SESSION_TYPE=wayland"
            "HOME=%h"
            "USER=%U"
            "PATH=%h/.local/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
            "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
            "XDG_CURRENT_DESKTOP=Hyprland"
          ];

          # Working directory
          WorkingDirectory = "%h";

          # Kill mode to ensure clean shutdown
          KillMode = "mixed";
          KillSignal = "SIGTERM";
          TimeoutStopSec = "30";
        };

        Install = {
          WantedBy = [ "hyprland-session.target" ];
        };
      };
    };
  };
}
