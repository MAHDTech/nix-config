{ pkgs, ... }:
{
  systemd.services.github-runner-bootstrap = {
    description = "Install the cloud-init selected GitHub runner host";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "cloud-final.service"
      "cloud-init-report.service"
    ];
    after = [
      "network-online.target"
      "cloud-final.service"
      "cloud-init-report.service"
    ];
    path = [
      pkgs.coreutils
      pkgs.cloud-init
      pkgs.systemd
      pkgs.nix
      pkgs.nixos-rebuild
      pkgs.git
      pkgs.openssh
    ];
    environment.RUNNER_FLAKE = "github:MAHDTech/nix-config";
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = "-/etc/github-runner-bootstrap";
      Restart = "on-failure";
      RestartSec = "5min";
      # Waiting for deployment credentials is not a failed or timed-out boot.
      TimeoutStartSec = "infinity";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -o pipefail
      # Cloud-init sets the runtime hostname on the neutral bootstrap image.
      runner_host="$(${pkgs.systemd}/bin/hostnamectl --transient)"
      case "$runner_host" in
        github-runner-0[1-9]|github-runner-10) ;;
        *) echo "cloud-init must set hostname to github-runner-01 through github-runner-10" >&2; exit 1 ;;
      esac
      echo "GitHub runner first-boot setup - $runner_host"
      cloud_status=0
      cloud-init status >/dev/null 2>&1 || cloud_status=$?
      if [ "$cloud_status" -ne 0 ] && [ "$cloud_status" -ne 2 ]; then
        echo "[1/4] Cloud-init has not completed successfully; inspect cloud-init status --long. Retry in 5 minutes." >&2
        exit 1
      fi
      echo "[1/4] Cloud-init complete"
      waited=0
      while [ ! -s /etc/opnix-token ]; do
        if [ "$((waited % 300))" -eq 0 ]; then
          echo "[2/4] Waiting for deployment to deliver the 1Password token"
          echo "      This is expected. Setup will continue automatically."
        fi
        sleep 5
        waited=$((waited + 5))
      done
      echo "[2/4] Token received"
      echo "[3/4] Building the runner configuration - this may take several minutes"
      echo "      Build log: journalctl -b -t github-runner-build"
      if timeout --kill-after=30s 2h nixos-rebuild boot \
        --flake "$RUNNER_FLAKE#$runner_host" --accept-flake-config \
        2>&1 | systemd-cat --identifier=github-runner-build; then
        echo "[4/4] Configuration ready - rebooting in one minute"
        echo "      Keep the VM powered on."
      else
        build_status=$?
        echo "[3/4] Build failed or exceeded its two-hour limit (exit $build_status). Retry in 5 minutes." >&2
        echo "      Inspect: journalctl -b -t github-runner-build" >&2
        exit 1
      fi
      ${pkgs.systemd}/bin/shutdown -r +1
    '';
  };
}
