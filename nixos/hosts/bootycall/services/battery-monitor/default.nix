{ pkgs, ... }:
{
  systemd.services.battery-monitor = {
    description = "CloudKey Battery Power-Loss Protection Monitor";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeScript "battery-monitor.sh" ''
        #!/bin/sh
        echo "Battery monitor started."
        while true; do
          if [ -f /sys/class/power_supply/battery/status ]; then
            STATUS=$(cat /sys/class/power_supply/battery/status)
            if [ "$STATUS" = "Discharging" ]; then
              echo "WARNING: Power cut detected! Running on battery. Initiating clean shutdown..."
              systemctl poweroff
              exit 0
            fi
          fi
          sleep 2
        done
      '';
      Restart = "always";
      RestartSec = 5;
    };
  };
}
