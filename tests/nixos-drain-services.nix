{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "nixos-drain-services";
  nodes.cache = { ... }: {
    imports = [ ../nixos/hosts/nix-cache/drain.nix ];
    system.stateVersion = import ../lib/stateVersion.nix;
    environment.systemPackages = [
      pkgs.curl
      pkgs.python3
    ];
    services.nginx = {
      enable = true;
      virtualHosts.localhost = {
        root = pkgs.runCommand "drain-fixture" { } ''
          mkdir -p $out
          head -c 1048576 /dev/zero > $out/archive
        '';
        locations."/".extraConfig = "limit_rate 64k;";
      };
    };
  };
  nodes.storage = { ... }: {
    imports = [ ../nixos/system/config/services/rustfs ];
    system.stateVersion = import ../lib/stateVersion.nix;
    virtualisation.memorySize = 2048;
    environment.systemPackages = [ (pkgs.python3.withPackages (ps: [ ps.boto3 ])) ];
    services.rustfs-managed = {
      enable = true;
      rootAccessKeyFile = "/run/test-access";
      rootSecretKeyFile = "/run/test-secret";
    };
    systemd.services = {
      rustfs = {
        requires = [ "fixture-secrets.service" ];
        after = [ "fixture-secrets.service" ];
      };
      fixture-secrets = {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        script = ''
          ${pkgs.openssl}/bin/openssl rand -hex 16 > /run/test-access
          ${pkgs.openssl}/bin/openssl rand -hex 32 > /run/test-secret
        '';
      };
    };
  };
  testScript = ''
    cache.start()
    cache.wait_for_unit("nginx.service")
    cache.succeed("systemctl show nginx -p KillSignal --value | grep '^3$'")
    cache.succeed("systemctl show nginx -p KillMode --value | grep '^mixed$'")
    cache.succeed("systemctl show nginx -p TimeoutStopUSec --value | grep '^5min$'")

    # An active response completes while new connections are refused.
    cache.succeed("sh -c 'curl --fail http://localhost/archive -o /run/download; echo $? > /run/download-result' > /run/curl.log 2>&1 &")
    cache.wait_until_succeeds("test -s /run/download")
    cache.succeed("nixos-drain drain --profile upgrade --owned > /run/attempt &")
    cache.wait_until_succeeds("systemctl show nginx -p ActiveState --value | grep deactivating")
    cache.wait_until_fails("curl --fail --max-time 1 http://localhost/archive -o /dev/null")
    cache.wait_until_succeeds("nixos-drain is-drained")
    cache.wait_for_file("/run/download-result")
    cache.succeed("test $(cat /run/download-result) -eq 0; test $(stat -c %s /run/download) -eq 1048576")
    cache.succeed("nixos-drain is-drained --attempt $(cat /run/attempt)")
    cache.fail("nixos-drain cancel --attempt another-attempt")
    cache.succeed("systemctl start nginx")
    cache.fail("systemctl is-active nginx")
    cache.succeed("nixos-drain cancel --attempt $(cat /run/attempt)")
    cache.wait_for_unit("nginx.service")

    # Cancelling an owned foreground caller restores the service after stop finishes.
    cache.succeed("curl --fail http://localhost/archive -o /run/download2 > /run/curl2.log 2>&1 &")
    cache.wait_until_succeeds("test -s /run/download2")
    cache.succeed("nixos-drain drain --profile upgrade --owned > /run/attempt2 & echo $! > /run/client-pid")
    cache.wait_until_succeeds("systemctl show nginx -p ActiveState --value | grep deactivating")
    cache.succeed("kill $(cat /run/client-pid)")
    cache.wait_until_succeeds("nixos-drain status | grep 'State:     cancelled'")
    cache.wait_for_unit("nginx.service")

    # Cancellation preserves a service that was already stopped before the drain.
    cache.succeed("systemctl stop nginx; nixos-drain drain --profile maintenance; nixos-drain cancel")
    cache.fail("systemctl is-active nginx")

    storage.start()
    storage.wait_for_unit("rustfs.service")
    storage.wait_for_unit("rustfs-provision.timer")
    client = "import boto3; s = boto3.client('s3', endpoint_url='http://127.0.0.1:9000', region_name='us-east-1', aws_access_key_id=open('/run/test-access').read().strip(), aws_secret_access_key=open('/run/test-secret').read().strip()); "
    storage.succeed(f"python3 -c \"{client}s.create_bucket(Bucket='drain-test'); s.put_object(Bucket='drain-test', Key='object', Body=b'preserved')\"")
    storage.succeed("nixos-drain drain --profile upgrade; nixos-drain is-drained")
    storage.fail("systemctl is-active rustfs")
    storage.fail("systemctl is-active rustfs-provision.timer")
    storage.succeed("systemctl start rustfs")
    storage.fail("systemctl is-active rustfs")
    storage.succeed("nixos-drain cancel")
    storage.wait_for_unit("rustfs.service")
    storage.wait_for_unit("rustfs-provision.timer")
    storage.succeed(f"python3 -c \"{client}assert s.get_object(Bucket='drain-test', Key='object')['Body'].read() == b'preserved'\"")
  '';
}
