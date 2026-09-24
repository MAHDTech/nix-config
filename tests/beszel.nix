# cspell:ignore pathlib urlsafe fetchall fetchone
{ pkgs, opnixModule }:
pkgs.testers.runNixOSTest {
  name = "beszel-managed";
  nodes = {
    hub = { lib, ... }: {
      imports = [
        opnixModule
        ../nixos/system/config/services/beszel
      ];
      networking.hosts."127.0.0.1" = [ "hub.example.test" ];
      services = {
        onepassword-secrets.enable = lib.mkForce false;
        beszel = {
          hub = {
            enable = true;
            dataDir = "/var/lib/beszel-fixture";
            port = 8190;
            systems.fixture = {
              host = "fixture";
            };
            opnix = {
              enable = true;
              privateKeyReference = "op://fixture/hub/private_key";
              bootstrapReference = "op://fixture/hub/bootstrap";
              tokenReferences.fixture = "op://fixture/agents/fixture";
            };
            frontend = {
              enable = true;
              domain = "hub.example.test";
              cloudflareTokenReference = "op://fixture/cloudflare/token";
            };
          };
          agent = {
            enable = true;
            environment = {
              HUB_URL = "https://hub.example.test";
              CA_CERT_FILE = "/var/lib/acme/hub.example.test/cert.pem";
            };
            opnix = {
              enable = true;
              publicKeyReference = "op://fixture/hub/public_key";
              tokenReference = "op://fixture/agents/fixture";
            };
          };
        };
      };
      systemd.services = {
        # Only secret delivery and external ACME issuance are mocked.
        opnix-secrets = {
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
          };
          script = ''
            ${pkgs.python3}/bin/python3 ${pkgs.writeText "beszel-fixture-secrets.py" ''
              import json
              from pathlib import Path
              import secrets
              import subprocess
              directory = Path('/run/secrets')
              directory.mkdir(exist_ok=True)
              key = directory / 'beszel-hub-private-key'
              if not key.exists():
                  subprocess.run(['${pkgs.openssh}/bin/ssh-keygen', '-q', '-t', 'ed25519', '-N', "", '-f', str(key)], check=True)
                  (directory / 'beszel-agent-key').write_text(Path(str(key) + '.pub').read_text())
                  token = secrets.token_urlsafe(32)
                  (directory / 'beszel-agent-token').write_text(token)
                  (directory / 'beszel-hub-token-fixture').write_text(token)
                  (directory / 'beszel-hub-bootstrap').write_text('USER_EMAIL=fixture@example.test\nUSER_PASSWORD=' + json.dumps(secrets.token_urlsafe(32)) + '\n')
                  (directory / 'cloudflare-acme-token').write_text(secrets.token_urlsafe(32))
            ''}
          '';
        };
        "acme-order-renew-hub.example.test".script = lib.mkForce "true";
        beszel-agent = {
          after = [ "nginx.service" ];
          serviceConfig.SupplementaryGroups = [ "nginx" ];
        };
      };
      environment.systemPackages = [
        pkgs.python3
        pkgs.curl
        pkgs.iproute2
      ];
    };
    client = _: {
      networking.hosts."192.168.1.2" = [ "hub.example.test" ];
    };
  };
  testScript = ''
    start_all()
    hub.wait_for_unit("nginx.service")
    hub.wait_for_unit("beszel-hub.service")
    hub.wait_for_unit("beszel-agent.service")
    hub.succeed("curl --fail --cacert /var/lib/acme/hub.example.test/cert.pem https://hub.example.test/api/health")
    client.succeed("curl -kf https://hub.example.test/api/health")
    client.fail("curl --connect-timeout 2 http://hub:8190/api/health")
    hub.succeed("test -z \"$(ss -ltnH 'sport = :45876')\"")
    database = "/var/lib/beszel-fixture/beszel_data/data.db"
    query = f"python3 -c \"import sqlite3; c=sqlite3.connect('{database}'); assert c.execute('SELECT status FROM systems').fetchall() == [('up',)]\""
    hub.wait_until_succeeds(query)
    before = hub.succeed(f"python3 -c \"import sqlite3; print(sqlite3.connect('{database}').execute('SELECT id FROM systems').fetchone()[0])\"").strip()
    hub.succeed("systemctl restart beszel-hub")
    hub.wait_until_succeeds(query)
    after = hub.succeed(f"python3 -c \"import sqlite3; print(sqlite3.connect('{database}').execute('SELECT id FROM systems').fetchone()[0])\"").strip()
    assert before == after
    hub.succeed("test $(stat -c %a /var/lib/beszel-fixture/beszel_data/config.yml) = 600")
    hub.succeed("test $(stat -c %a /var/lib/beszel-fixture/beszel_data/id_ed25519) = 600")
    hub.succeed("systemctl stop beszel-hub; cp /var/lib/beszel-fixture/beszel_data/config.yml /run/previous-inventory; truncate -s 0 /run/secrets/beszel-hub-token-fixture")
    hub.fail("systemctl start beszel-hub")
    hub.succeed("cmp /run/previous-inventory /var/lib/beszel-fixture/beszel_data/config.yml")
    hub.succeed("cp /run/secrets/beszel-agent-token /run/secrets/beszel-hub-token-fixture; systemctl reset-failed beszel-hub; systemctl start beszel-hub")
    hub.wait_until_succeeds(query)
  '';
}
