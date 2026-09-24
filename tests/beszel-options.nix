{ pkgs, opnixModule }:
let
  inherit (pkgs) lib;
  evaluate =
    extra:
    (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [
        opnixModule
        ../nixos/system/config/services/beszel
        extra
      ];
    }).config;
  disabled = evaluate { };
  managedHub = evaluate {
    services.beszel.hub = {
      enable = true;
      opnix = {
        enable = true;
        privateKeyReference = "op://fixture/hub/key";
        bootstrapReference = "op://fixture/hub/bootstrap";
        tokenReferences = {
          github-runner-01 = "op://fixture/agents/github-runner-01";
          nix-cache = "op://fixture/agents/nix-cache";
        };
      };
    };
  };
  hub = evaluate {
    services.beszel.hub = {
      enable = true;
      host = "127.0.0.2";
      port = 8390;
      dataDir = "/var/lib/custom-hub";
      environmentFile = "/run/custom-bootstrap";
      environment.APP_URL = "https://test.example.test";
      opnix = {
        enable = true;
        privateKeyReference = "op://fixture/hub/key";
        bootstrapReference = "op://fixture/hub/bootstrap";
      };
    };
  };
  agent = evaluate {
    services.beszel.agent = {
      enable = true;
      package = pkgs.beszel;
      dataDir = "/var/lib/custom-agent";
      environmentFile = "/run/custom-agent-env";
      extraPath = [ pkgs.curl ];
      openFirewall = true;
      environment = {
        SKIP_SYSTEMD = true;
        PORT = "45900";
        DISABLE_SSH = "false";
      };
      smartmon = {
        enable = true;
        package = pkgs.smartmontools;
        deviceAllow = [ "/dev/sda" ];
      };
    };
  };
in
assert !disabled.services.beszel.hub.enable && !disabled.services.beszel.agent.enable;
assert !(disabled.systemd.services ? beszel-hub) && !(disabled.systemd.services ? beszel-agent);
assert hub.services.beszel.hub.systems == null;
assert builtins.stringLength managedHub.systemd.services.opnix-secrets.script > 0;
assert
  !(lib.any (
    assertion: !assertion.assertion && lib.hasPrefix "Beszel" assertion.message
  ) hub.assertions);
assert hub.services.beszel.hub.host == "127.0.0.2" && hub.services.beszel.hub.port == 8390;
assert hub.systemd.services.beszel-hub.serviceConfig.WorkingDirectory == "/var/lib/custom-hub";
assert hub.systemd.services.beszel-hub.serviceConfig.EnvironmentFile == "/run/custom-bootstrap";
assert hub.systemd.services.beszel-hub.environment.APP_URL == "https://test.example.test";
assert agent.systemd.services.beszel-agent.serviceConfig.EnvironmentFile == "/run/custom-agent-env";
assert agent.systemd.services.beszel-agent.environment.DATA_DIR == "/var/lib/custom-agent";
assert agent.systemd.services.beszel-agent.environment.SKIP_SYSTEMD == "true";
assert agent.systemd.services.beszel-agent.environment.DISABLE_SSH == "false";
assert builtins.elem pkgs.curl agent.systemd.services.beszel-agent.path;
assert builtins.elem pkgs.smartmontools agent.systemd.services.beszel-agent.path;
assert agent.systemd.services.beszel-agent.serviceConfig.DeviceAllow == [ "/dev/sda r" ];
assert builtins.elem 45900 agent.networking.firewall.allowedTCPPorts;
pkgs.runCommand "beszel-option-compatibility" { } "touch $out"
