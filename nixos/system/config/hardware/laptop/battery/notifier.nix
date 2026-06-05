{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.batteryNotifier;
in
{
  options = {
    services.batteryNotifier = {
      enable = mkOption {
        default = false;
        description = ''
          Whether to enable battery notifier.
        '';
      };

      device = mkOption {
        default = "BAT0";
        description = ''
          Device to monitor.
        '';
      };

      notifyCapacity = mkOption {
        default = 10;
        description = ''
          Battery level at which a notification shall be sent.
        '';
      };

      suspendCapacity = mkOption {
        default = 5;
        description = ''
          Battery level at which a suspend unless connected shall be sent.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.timers."lowbatt" = {
      description = "check battery level";
      timerConfig = {
        OnBootSec = "1m";
        OnUnitInactiveSec = "1m";
        Unit = "lowbatt.service";
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.user.services."lowbatt" = {
      description = "battery level notifier";
      serviceConfig = {
        PassEnvironment = "DISPLAY";
        ExecStartPre = pkgs.writeShellScript "lowbatt-pre-start" ''
          ${pkgs.coreutils}/bin/echo "Executing pre-start script for lowbatt"
        '';
        ExecStart = pkgs.writeShellScript "lowbatt-start" ''
          ${pkgs.coreutils}/bin/echo "Executing start script for lowbatt"

          # Guard: exit gracefully if battery device is not yet available
          # (Qualcomm ADSP may not have initialised qcom-battmgr-bat yet)
          if [ ! -d /sys/class/power_supply/${cfg.device} ]; then
            ${pkgs.coreutils}/bin/echo "Battery device ${cfg.device} not yet available, skipping check"
            exit 0
          fi

          export battery_status=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/status 2>/dev/null || echo "Unknown")

          # Skip check if battery status is not yet meaningful
          if [ "$battery_status" = "Unknown" ] || [ "$battery_status" = "" ]; then
            ${pkgs.coreutils}/bin/echo "Battery status is '$battery_status', skipping check"
            exit 0
          fi

          if [ -f /sys/class/power_supply/${cfg.device}/capacity ]; then
            export battery_capacity=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/capacity)
          elif [ -f /sys/class/power_supply/${cfg.device}/energy_now ] && [ -f /sys/class/power_supply/${cfg.device}/energy_full ]; then
            energy_now=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/energy_now)
            energy_full=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/energy_full)
            if [ "$energy_full" -gt 0 ]; then
              export battery_capacity=$(( energy_now * 100 / energy_full ))
            else
              export battery_capacity=100
            fi
          elif [ -f /sys/class/power_supply/${cfg.device}/charge_now ] && [ -f /sys/class/power_supply/${cfg.device}/charge_full ]; then
            charge_now=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/charge_now)
            charge_full=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/charge_full)
            if [ "$charge_full" -gt 0 ]; then
              export battery_capacity=$(( charge_now * 100 / charge_full ))
            else
              export battery_capacity=100
            fi
          else
            export battery_capacity=100
          fi

          if [[ $battery_capacity -le ${builtins.toString cfg.notifyCapacity} && $battery_status = "Discharging" ]];
          then
            ${pkgs.libnotify}/bin/notify-send --urgency=critical --hint=int:transient:1 --icon=battery_empty "Battery Low" "You should probably plug-in."
          fi

          if [[ $battery_capacity -le ${builtins.toString cfg.suspendCapacity} && $battery_status = "Discharging" ]];
          then
            ${pkgs.libnotify}/bin/notify-send --urgency=critical --hint=int:transient:1 --icon=battery_empty "Battery Critically Low" "Computer will suspend in 60 seconds."
            sleep 60s
            battery_status=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/${cfg.device}/status)
            if [[ $battery_status = "Discharging" ]];
            then
              systemctl suspend
            fi
          fi
        '';
        ExecStartPost = pkgs.writeShellScript "lowbatt-post-start" ''
          ${pkgs.coreutils}/bin/echo "Executing post-start script for lowbatt"
        '';
      };
    };
  };
}
