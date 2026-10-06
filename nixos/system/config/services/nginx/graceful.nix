{ config, lib, ... }:
{
  systemd.services.nginx = lib.mkIf config.services.nginx.enable {
    serviceConfig = {
      KillSignal = "SIGQUIT";
      KillMode = "mixed";
      TimeoutStopSec = "5min";
    };
  };
}
