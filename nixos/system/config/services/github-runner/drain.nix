{
  config,
  lib,
  pkgs,
  ...
}:
let
  runners = lib.filterAttrs (_: runner: runner.enable) config.services.github-runners;
  units = map (name: "github-runner-${name}.service") (builtins.attrNames runners);
  runnerConfig = pkgs.writeText "github-runner-drain.json" (
    builtins.toJSON (
      lib.mapAttrs' (
        name: runner:
        lib.nameValuePair "github-runner-${name}.service" {
          inherit (runner) name url tokenFile;
        }
      ) runners
    )
  );
  handler = pkgs.writeShellApplication {
    name = "github-runner-drain";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      export GITHUB_RUNNER_DRAIN_CONFIG=${lib.escapeShellArg (toString runnerConfig)}
      exec python3 ${./drain.py} "$@" ${lib.escapeShellArgs units}
    '';
  };
  profile = {
    script = "${handler}/bin/github-runner-drain drain";
    cancelScript = "${handler}/bin/github-runner-drain cancel";
  };
in
{
  imports = [ ../nixos-drain ];

  assertions = [
    {
      assertion = lib.all (runner: runner.ephemeral && runner.count == 1 && runner.orgs == { }) (
        lib.attrValues runners
      );
      message = "GitHub runner draining requires ephemeral runners with one registration per service.";
    }
  ];
  services.nixos-drain = {
    enable = true;
    profiles = {
      upgrade = profile // {
        cancelOnFailure = true;
      };
      destroy = profile;
      maintenance = profile;
    };
  };
  # Ephemeral registrations pick up new tokens naturally without interrupting a job.
  services.github-runner-fleet.restartOnTokenChange = false;
  environment.systemPackages = [ handler ];
  systemd.tmpfiles.rules = [ "d /run/nixos-drain/github-runners 0755 root root -" ];
  systemd.services = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "github-runner-${name}" {
      # Ephemeral registrations adopt the new unit on their next natural start.
      restartIfChanged = false;
      environment.GITHUB_RUNNER_DRAIN_MARKER = "/run/nixos-drain/github-runners/maintenance";
      serviceConfig.ExecCondition = [ "+${handler}/bin/github-runner-drain gate" ];
    }
  ) runners;
}
