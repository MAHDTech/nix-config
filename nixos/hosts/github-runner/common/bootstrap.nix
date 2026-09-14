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
    };
    script = ''
      runner_host="$(${pkgs.systemd}/bin/hostnamectl --static)"
      case "$runner_host" in
        github-runner-0[1-4]) ;;
        *) echo "cloud-init must set hostname to github-runner-01 through github-runner-04" >&2; exit 1 ;;
      esac
      test -s /etc/opnix-token
      nixos-rebuild boot --flake "$RUNNER_FLAKE#$runner_host" --accept-flake-config
      ${pkgs.systemd}/bin/shutdown -r +1
    '';
  };
}
