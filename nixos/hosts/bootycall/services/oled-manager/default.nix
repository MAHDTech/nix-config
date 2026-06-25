{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.oled-manager;
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pillow ]);
  configFile = pkgs.writeText "oled-manager-config.json" (
    builtins.toJSON {
      poll_interval = cfg.pollInterval;
      enabled_metrics = cfg.enabledMetrics;
    }
  );
in
{
  options.services.oled-manager = {
    enable = mkEnableOption "CloudKey OLED Screen Manager";
    pollInterval = mkOption {
      type = types.int;
      default = 60;
      description = "Refresh interval in seconds";
    };
    enabledMetrics = mkOption {
      type = types.listOf types.str;
      default = [
        "hostname"
        "ip"
        "cpu_temp"
        "load"
        "uptime"
      ];
      description = "List of metrics to render";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.oled-manager = {
      description = "CloudKey OLED Screen Manager";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pythonEnv}/bin/python3 ${./oled-manager.py} --config ${configFile}";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
