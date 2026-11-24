{ lib, ... }:
{
  imports = [
    (import ../../system/config/services/nixos-drain/service-profile.nix {
      name = "mirror";
      units = [
        "mirror-summary.timer"
        "mirror-summary.service"
        "caddy.service"
      ];
      timeoutSeconds = 360;
    })
  ];

  services.caddy.globalConfig = lib.mkAfter ''
    grace_period 5m
  '';

  systemd.services.caddy.serviceConfig.TimeoutStopSec = "330s";
}
