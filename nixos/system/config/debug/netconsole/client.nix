{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.debug.netconsole.client;
in
{
  options.debug.netconsole.client = {
    enable = mkEnableOption "netconsole client";

    interface = mkOption {
      type = types.str;
      description = "Network interface to send netconsole logs from.";
    };

    clientIp = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Static IP address for the client. If null, the service will dynamically query the IP on the interface.";
    };

    server = {
      ip = mkOption {
        type = types.str;
        description = "IP address of the netconsole server.";
      };
      port = mkOption {
        type = types.port;
        default = 6666;
        description = "Port of the netconsole server.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.netconsole = {
      description = "Load netconsole for remote crash capture";
      after = [
        "network-online.target"
        "sys-subsystem-net-devices-${cfg.interface}.device"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "start-netconsole" ''
          ${
            if cfg.clientIp != null then
              ''
                SRC_IP="${cfg.clientIp}"
              ''
            else
              ''
                SRC_IP=$(${pkgs.iproute2}/bin/ip -4 addr show ${cfg.interface} | ${pkgs.gnugrep}/bin/grep -oP 'inet \K[\d.]+')
              ''
          }
          if [ -z "$SRC_IP" ]; then
            echo "netconsole: ${cfg.interface} has no IP, skipping"
            exit 0
          fi
          ${pkgs.kmod}/bin/modprobe netconsole "netconsole=@$SRC_IP/${cfg.interface},${toString cfg.server.port}@${cfg.server.ip}/"
          echo "netconsole: configured with source IP $SRC_IP -> ${cfg.server.ip}:${toString cfg.server.port}"
        '';
        ExecStop = "${pkgs.kmod}/bin/modprobe -r netconsole";
      };
    };
  };
}
