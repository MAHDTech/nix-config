{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "nixos-drain";
  nodes = {
    runner = { lib, ... }: {
      imports = [ ../nixos/system/config/services/github-runner/drain.nix ];
      options.services.github-runner-fleet.restartOnTokenChange = lib.mkOption {
        type = lib.types.bool;
      };
      config = {
        environment.systemPackages = [ pkgs.python3 ];
        services.nixos-drain.timeoutSeconds = 8;
        services.github-runners.test = {
          enable = true;
          ephemeral = true;
          tokenFile = "/run/unused-token";
          url = "https://github.com/example";
          user = "root";
        };
        systemd.services.github-runner-test.serviceConfig = {
          ExecStartPre = lib.mkForce [ ];
          InaccessiblePaths = lib.mkForce [ ];
          ReadWritePaths = [ "/run" ];
          ExecStart = lib.mkForce (
            pkgs.writeShellScript "fake-runner" ''
              echo started >> /run/registrations
              touch /run/job-active
              while [ ! -e /run/finish-job ]; do sleep 0.1; done
              rm /run/job-active /run/finish-job
              touch /run/job-completed
            ''
          );
          Restart = lib.mkForce "always";
          RestartSec = "100ms";
          PrivateUsers = false;
        };
      };
    };
    plain = { ... }: {
      imports = [ ../nixos/system/config/services/nixos-drain ];
      services.nixos-drain = {
        enable = true;
        profiles.failure.script = "exit 7";
      };
    };
  };
  testScript = ''
    start_all()
    plain.wait_for_unit("multi-user.target")
    plain.succeed("nixos-drain status | grep idle")
    plain.succeed("nixos-drain drain --profile maintenance")
    plain.succeed("nixos-drain status | grep notification-only")
    plain.succeed("su -s /bin/sh nobody -c 'nixos-drain status' | grep drained")
    plain.fail("su -s /bin/sh nobody -c 'nixos-drain drain --profile maintenance'")
    plain.fail("nixos-drain drain --profile destroy")
    plain.succeed("nixos-drain cancel")
    plain.fail("nixos-drain drain --profile failure")
    plain.succeed("nixos-drain status | grep failed")
    plain.succeed("nixos-drain cancel")

    runner.wait_for_file("/run/job-active")
    runner.succeed("nixos-drain drain --profile destroy > /run/drain-client.log 2>&1 & echo $! > /run/client-pid")
    runner.wait_for_file("/run/nixos-drain/github-runners/maintenance")
    runner.succeed("kill $(cat /run/client-pid)")
    runner.succeed("nixos-drain status | grep 'State:     draining'")
    runner.succeed("test -f /run/job-active")
    runner.succeed("touch /run/finish-job")
    runner.wait_until_succeeds("nixos-drain status | grep 'State:     drained'")
    runner.succeed("test -f /run/job-completed; test $(wc -l < /run/registrations) -eq 1")
    runner.succeed("systemctl start github-runner-test; test ! -e /run/job-active")
    runner.succeed("nixos-drain drain --profile destroy")
    runner.succeed("nixos-drain cancel")
    runner.wait_for_file("/run/job-active")

    # Cancellation leaves an in-flight job alive and the waiting caller fails.
    runner.succeed("sh -c 'nixos-drain drain --profile upgrade; echo $? > /run/client-result' > /run/client.log 2>&1 &")
    runner.wait_for_file("/run/nixos-drain/github-runners/maintenance")
    runner.succeed("nixos-drain cancel")
    runner.wait_for_file("/run/client-result")
    runner.succeed("test $(cat /run/client-result) -ne 0; test -f /run/job-active")
    runner.succeed("test $(wc -l < /run/registrations) -eq 2")

    # An idle registration is also allowed to wait for its final job until timeout.
    runner.fail("nixos-drain drain --profile upgrade")
    runner.succeed("nixos-drain status | grep 'Drain cancelled after failure'")
    runner.succeed("test -f /run/job-active; test ! -e /run/nixos-drain/github-runners/maintenance")
    runner.succeed("touch /run/finish-job")
    runner.wait_until_succeeds("test $(wc -l < /run/registrations) -eq 3")
    runner.wait_for_file("/run/job-active")

    # A destroy timeout still blocks registration until an explicit cancel.
    runner.fail("nixos-drain drain --profile destroy")
    runner.succeed("nixos-drain status | grep timed-out")
    runner.succeed("test -f /run/nixos-drain/github-runners/maintenance")
    runner.succeed("nixos-drain cancel")

    # Worker termination also restores registration for upgrade profiles.
    runner.succeed("nixos-drain drain --profile upgrade > /run/client.log 2>&1 &")
    runner.wait_for_file("/run/nixos-drain/github-runners/maintenance")
    runner.succeed("systemctl stop $(python3 -c 'import json; print(json.load(open(\"/run/nixos-drain/status.json\"))[\"unit\"])')")
    runner.wait_until_succeeds("nixos-drain status | grep 'State:     cancelled'")
    runner.succeed("test -f /run/job-active; test ! -e /run/nixos-drain/github-runners/maintenance")

    # An abruptly stopped worker cannot leave a caller waiting forever.
    runner.succeed("nixos-drain drain --profile maintenance > /run/client.log 2>&1 &")
    runner.wait_for_file("/run/nixos-drain/github-runners/maintenance")
    runner.succeed("systemctl stop $(python3 -c 'import json; print(json.load(open(\"/run/nixos-drain/status.json\"))[\"unit\"])')")
    runner.succeed("nixos-drain status | grep failed; test -f /run/job-active")
    runner.succeed("nixos-drain cancel")

    runner.succeed("nixos-drain drain --profile destroy > /run/client.log 2>&1 &")
    runner.wait_for_file("/run/nixos-drain/github-runners/maintenance")
    runner.succeed("touch /run/finish-job")
    runner.wait_until_succeeds("nixos-drain status | grep 'State:     drained'")
    runner.succeed("reboot")
    runner.wait_for_shutdown()
    runner.start()
    runner.wait_for_unit("multi-user.target")
    runner.succeed("nixos-drain status | grep idle")
    runner.wait_for_file("/run/job-active")
  '';
}
