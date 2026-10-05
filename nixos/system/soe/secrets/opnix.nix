{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Every host shares one 1Password account limited to 1000 requests per day,
  # so failed resolutions must back off or the fleet exhausts the quota and
  # nothing can recover. Restart= alone cannot do this: dependents with
  # Restart=always pull the unit in via Wants= on every cycle, bypassing
  # RestartSec. Clear /var/lib/opnix-backoff to retry immediately once
  # 1Password is fixed.
  backoff = rec {
    stateDir = "/var/lib/opnix-backoff";
    baseSeconds = 60;
    # Keeps a persistently failing hub (33 references) to ~4 attempts per day.
    maxSeconds = 6 * 3600;
    path = lib.makeBinPath [ pkgs.coreutils ];

    # Sleeps out any pending backoff. Concurrent start requests merge into this
    # one activating job; a restart re-enters with the same persisted deadline.
    # A new system generation gets one immediate attempt so deploys that fix a
    # reference (and switch-to-configuration) are not held up.
    gate = pkgs.writeShellScript "opnix-backoff-gate" ''
      export PATH=${path}
      generation=$(readlink /run/current-system || true)
      if [ "$(cat ${stateDir}/generation 2>/dev/null)" != "$generation" ]; then
        exit 0
      fi
      next=$(cat ${stateDir}/next 2>/dev/null || echo 0)
      now=$(date +%s)
      if [ "$now" -lt "$next" ]; then
        echo "OpNix backing off after $(cat ${stateDir}/failures) consecutive failures; next 1Password attempt at $(date -d "@$next")"
        sleep $((next - now))
      fi
    '';

    # ExecStartPost: the run succeeded.
    reset = pkgs.writeShellScript "opnix-backoff-reset" ''
      rm -f ${stateDir}/failures ${stateDir}/next ${stateDir}/generation
    '';

    # ExecStopPost: count real failures only. Manual stops and restarts that
    # kill the gate leave the schedule untouched.
    record = pkgs.writeShellScript "opnix-backoff-record" ''
      export PATH=${path}
      case "$SERVICE_RESULT" in
        exit-code | timeout | core-dump | watchdog) ;;
        *) exit 0 ;;
      esac
      failures=$(( $(cat ${stateDir}/failures 2>/dev/null || echo 0) + 1 ))
      delay=${toString baseSeconds}
      for _ in $(seq 2 "$failures"); do
        delay=$((delay * 2))
        [ "$delay" -ge ${toString maxSeconds} ] && { delay=${toString maxSeconds}; break; }
      done
      # Jitter de-synchronises hosts that failed together.
      delay=$((delay + RANDOM % (delay / 4 + 1)))
      echo "$failures" > ${stateDir}/failures
      echo $(( $(date +%s) + delay )) > ${stateDir}/next
      readlink /run/current-system > ${stateDir}/generation || true
      echo "OpNix failure $failures; backing off ''${delay}s before the next 1Password attempt"
    '';
  };

  # The deployment controller installs the token out of band (cloud-init only
  # lists it as a bootstrap prerequisite). Upstream opnix exits 0 without a
  # token, which would start dependents with no secrets, so wait for it.
  tokenFile = config.services.onepassword-secrets.tokenFile;
  tokenWait = pkgs.writeShellScript "opnix-token-wait" ''
    until [ -s ${tokenFile} ]; do
      echo "Waiting for the deployment controller to deliver ${tokenFile}"
      ${pkgs.coreutils}/bin/sleep 30
    done
  '';
in
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
    tmpfiles.rules = [
      "d /var/lib/nixos-bootstrap 0700 root root -"
      "d ${backoff.stateDir} 0700 root root -"
    ];
    services = {
      opnix-secrets = {
        # The gate owns retry pacing; a start limit would wedge the unit failed
        # and stop it ever recovering once 1Password is fixed.
        unitConfig.StartLimitIntervalSec = lib.mkForce 0;
        serviceConfig = {
          Restart = lib.mkForce "on-failure";
          RestartSec = lib.mkForce "10s";
          # Retry missing references too, so fixing 1Password self-heals.
          RestartPreventExitStatus = lib.mkForce [ ];
          # The token may take arbitrarily long to arrive on a fresh guest.
          TimeoutStartSec = lib.mkDefault "infinity";
          ExecStartPre = lib.mkBefore [
            "${tokenWait}"
            "${backoff.gate}"
          ];
          ExecStartPost = [ "${backoff.reset}" ];
          ExecStopPost = [ "${backoff.record}" ];
        };
      };
      # Re-resolves every reference itself, so it must honour the same backoff.
      opnix-secrets-restart =
        lib.mkIf config.services.onepassword-secrets.systemdIntegration.changeDetection.enable
          {
            serviceConfig.ExecStartPre = [ "${backoff.gate}" ];
          };
      opnix-pending-refresh = {
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
