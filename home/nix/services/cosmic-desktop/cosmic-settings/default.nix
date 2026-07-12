{ pkgs, ... }: {
  systemd.user.services.cosmic-settings-daemon = {
    Unit = {
      Description = "COSMIC Settings Daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.cosmic-settings-daemon}/bin/cosmic-settings-daemon";
      Restart = "on-failure";
      RestartSec = "5";
      Environment = [
        "XDG_RUNTIME_DIR=%t"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
      ];
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
