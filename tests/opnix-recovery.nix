{ pkgs, opnixModule }:
let
  stateVersion = import ../lib/stateVersion.nix;
in
pkgs.testers.runNixOSTest {
  name = "opnix-recovery";
  nodes.machine =
    { lib, ... }:
    {
      system.stateVersion = stateVersion;
      imports = [
        opnixModule
        ../nixos/system/soe/secrets/opnix.nix
      ];
      environment.etc."opnix-token".text = "dummy-test-token\n";
      services = {
        onepassword-secrets.secrets.appSecret = {
          reference = "op://test/app/secret";
          path = "/run/secrets/app-secret";
          owner = "root";
          group = "root";
          mode = "0400";
          services = [ "app-secret" ];
        };
        opnix.dependentServices = [
          "app-wait-only"
          "app-drained"
        ];
      };
      systemd.services = {
        opnix-secrets = {
          # Replace only the 1Password CLI call; keep production ExecStartPre,
          # ExecStartPost (opnix-backoff-reset) and ExecStopPost (opnix-backoff-record).
          script = lib.mkForce ''
            mkdir -p /run/secrets
            counter=/var/lib/opnix-test-attempts
            count=0
            if [ -f "$counter" ]; then count=$(cat "$counter"); fi
            count=$((count + 1))
            echo "$count" > "$counter"
            if [ "$count" -eq 1 ] || [ -e /run/opnix-force-fail ]; then
              echo "Simulated transient 1Password failure (attempt $count)" >&2
              exit 1
            fi
            echo "secret-value" > /run/secrets/app-secret
          '';
        };
        app-secret = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = pkgs.writeShellScript "app-secret" ''
              test -f /run/secrets/app-secret
              touch /run/app-secret-started
              exec ${pkgs.coreutils}/bin/sleep infinity
            '';
          };
        };
        app-wait-only = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = "1s";
            ExecStart = pkgs.writeShellScript "app-wait-only" ''
              test -f /run/secrets/app-secret
              touch /run/app-wait-only-started
              exec ${pkgs.coreutils}/bin/sleep infinity
            '';
          };
        };
        app-drained = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecCondition = "${pkgs.coreutils}/bin/test ! -e /run/app-drained-blocked";
            ExecStart = pkgs.writeShellScript "app-drained" ''
              touch /run/app-drained-started
              exec ${pkgs.coreutils}/bin/sleep infinity
            '';
          };
        };
      };
    };
  testScript = ''
    machine.start()
    machine.wait_for_unit("systemd-tmpfiles-setup.service")

    # Wait until the first boot attempt fails and records backoff state.
    machine.wait_until_succeeds("test -f /var/lib/opnix-backoff/failures", timeout=30)
    machine.succeed("test $(cat /var/lib/opnix-backoff/failures) -eq 1")

    # Dependents must have waited for opnix-secrets and stayed inactive (never started without secrets).
    for unit in ("app-secret.service", "app-wait-only.service", "app-drained.service"):
        machine.succeed(f"systemctl show {unit} -p Wants --value | grep -q opnix-secrets.service")
        machine.succeed(f"systemctl show {unit} -p After --value | grep -q opnix-secrets.service")
        machine.succeed(f"test $(systemctl show {unit} -p ActiveState --value) = inactive")
    machine.succeed("test ! -e /run/app-secret-started && test ! -e /run/app-wait-only-started")

    # Mark app-drained as blocked by a drain gate before opnix recovers.
    machine.succeed("touch /run/app-drained-blocked")

    # Fast-forward the backoff deadline and let systemd's own Restart=on-failure
    # (RestartSec=10s) retry opnix-secrets.service automatically.
    machine.succeed("echo 0 > /var/lib/opnix-backoff/next")

    # Recovery must clear backoff and automatically start inactive dependents while respecting ExecCondition.
    machine.wait_until_succeeds("test $(systemctl show app-secret.service -p ActiveState --value) = active", timeout=30)
    machine.wait_until_succeeds("test $(systemctl show app-wait-only.service -p ActiveState --value) = active", timeout=30)
    machine.succeed("test ! -e /var/lib/opnix-backoff/failures")
    machine.succeed("test $(systemctl show app-drained.service -p ActiveState --value) = inactive")
    machine.succeed("test ! -e /run/app-drained-started")

    # A clean restart of opnix-secrets (no prior failure) must not start a manually stopped service.
    original_pid = machine.succeed("systemctl show app-secret.service -p MainPID --value").strip()
    machine.succeed("systemctl stop app-wait-only.service")
    machine.succeed("systemctl restart opnix-secrets.service")
    machine.succeed("test $(systemctl show app-wait-only.service -p ActiveState --value) = inactive")
    assert machine.succeed("systemctl show app-secret.service -p MainPID --value").strip() == original_pid

    # A subsequent transient failure + recovery must not restart an already-running dependent.
    machine.succeed("touch /run/opnix-force-fail")
    machine.fail("systemctl restart opnix-secrets.service")
    machine.wait_until_succeeds("test -f /var/lib/opnix-backoff/failures", timeout=20)
    machine.succeed("rm -f /run/opnix-force-fail && echo 0 > /var/lib/opnix-backoff/next")
    machine.succeed("systemctl restart opnix-secrets.service")
    machine.wait_until_succeeds("test $(systemctl show app-wait-only.service -p ActiveState --value) = active", timeout=20)
    assert machine.succeed("systemctl show app-secret.service -p MainPID --value").strip() == original_pid
  '';
}
