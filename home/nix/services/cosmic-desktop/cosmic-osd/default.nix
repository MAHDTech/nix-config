{ pkgs, ... }: {
  systemd.user.services.cosmic-osd = {
    Unit = {
      Description = "COSMIC OSD Daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.cosmic-osd}/bin/cosmic-osd";
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
