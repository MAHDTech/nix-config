{ pkgs, opnixModule }:
let
  domains = [
    "api.example.test"
    "console.example.test"
  ];
in
pkgs.testers.runNixOSTest {
  name = "cloudflare-acme-retry";
  nodes.machine = { lib, ... }: {
    imports = [
      opnixModule
      ../nixos/system/config/services/cloudflare-acme
    ];
    services = {
      cloudflare-acme = {
        enable = true;
        inherit domains;
        tokenReference = "op://test/cloudflare/token";
        tokenPath = "/run/test-cloudflare-token";
        retryIntervalSeconds = 1;
      };
      nginx.enable = true;
      onepassword-secrets.enable = lib.mkForce false;
    };
    systemd.services = {
      opnix-secrets = {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "touch /run/test-cloudflare-token";
      };
    }
    // lib.genAttrs (map (domain: "acme-order-renew-${domain}") domains) (name: {
      # Exercise the generated units without contacting Cloudflare or Let's Encrypt.
      script = lib.mkForce ''
        counter=/var/lib/acme/${name}.attempts
        count=0
        if test -f "$counter"; then count=$(cat "$counter"); fi
        count=$((count + 1))
        echo "$count" > "$counter"
        if test "$count" -lt 3; then exit 10; fi
      '';
    });
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    for domain in ${builtins.toJSON domains}:
        unit = f"acme-order-renew-{domain}"
        machine.succeed(f"test $(systemctl show {unit} -p Restart --value) = on-failure")
        machine.succeed(f"systemctl start --no-block {unit}")
        machine.wait_until_succeeds(f"test $(cat /var/lib/acme/{unit}.attempts) -eq 3", timeout=30)
        machine.wait_until_succeeds(f"test $(systemctl show {unit} -p ActiveState --value) = inactive")
        machine.succeed(f"test $(systemctl show {unit} -p Result --value) = success")
        machine.succeed("sleep 3")
        machine.succeed(f"test $(cat /var/lib/acme/{unit}.attempts) -eq 3")
  '';
}
