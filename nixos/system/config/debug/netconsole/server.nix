{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.debug.netconsole.server;
in
{
  options.debug.netconsole.server = {
    enable = mkEnableOption "netconsole receiver server";

    port = mkOption {
      type = types.port;
      default = 6666;
      description = "Port to listen for netconsole UDP packets.";
    };

    logFile = mkOption {
      type = types.str;
      default = "/var/log/netconsole.log";
      description = "File to append netconsole logs to.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the firewall port for netconsole.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.netconsole-receiver = {
      description = "Netconsole UDP receiver";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nmap}/bin/ncat --udp -l ${toString cfg.port} -k";
        StandardOutput = "append:${cfg.logFile}";
        StandardError = "journal";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
