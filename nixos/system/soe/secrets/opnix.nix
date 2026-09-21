{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.onepassword-secrets = {
    enable = lib.mkDefault (
      config.services.onepassword-secrets.secrets != { }
      || config.services.onepassword-secrets.configFiles != [ ]
    );
    tokenFile = "/etc/opnix-token";
    secrets = { };
  };

  # Tasks atomically install tokens and leave this marker, including while a
  # guest is adopting its final OS. Refresh does not need a controller watcher.
  systemd = lib.mkIf config.services.onepassword-secrets.enable {
    tmpfiles.rules = [ "d /var/lib/nixos-bootstrap 0700 root root -" ];
    services.opnix-pending-refresh = {
      description = "Reconcile pending OpNix credentials after adoption";
      after = [ "opnix-secrets.service" ];
      path = with pkgs; [
        coreutils
        util-linux
        systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
      };
      script = ''
        exec 9>/var/lib/nixos-bootstrap/opnix.lock
        flock -n 9 || exit 0
        if test -e /var/lib/nixos-bootstrap/opnix-pending && test -s /etc/opnix-token; then
          systemctl restart opnix-secrets.service
          rm -f /var/lib/nixos-bootstrap/opnix-pending
        fi
      '';
    };
    timers.opnix-pending-refresh = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitInactiveSec = "1min";
      };
    };
  };
}
