{ pkgs, ... }:
{
  systemd.services.github-runner-bootstrap = {
    description = "Install the cloud-init selected GitHub runner host";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "cloud-final.service"
    ];
    after = [
      "network-online.target"
      "cloud-final.service"
    ];
    path = [
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
      TimeoutStartSec = "2h";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      # Cloud-init sets the runtime hostname on the neutral bootstrap image.
      runner_host="$(${pkgs.systemd}/bin/hostnamectl --transient)"
      case "$runner_host" in
        github-runner-0[1-4]) ;;
        *) echo "cloud-init must set hostname to github-runner-01 through github-runner-04" >&2; exit 1 ;;
      esac
      echo "Runner bootstrap: selected host $runner_host"
      if [ ! -s /etc/opnix-token ]; then
        echo "Runner bootstrap: waiting for SSH delivery of /etc/opnix-token; retry in 5 minutes" >&2
        exit 1
      fi
      echo "Runner bootstrap: building the boot configuration for $runner_host"
      if ! nixos-rebuild boot --flake "$RUNNER_FLAKE#$runner_host" --accept-flake-config; then
        echo "Runner bootstrap: rebuild failed; retry in 5 minutes" >&2
        exit 1
      fi
      echo "Runner bootstrap: configuration ready; reboot scheduled in 1 minute"
      ${pkgs.systemd}/bin/shutdown -r +1
    '';
  };
}
