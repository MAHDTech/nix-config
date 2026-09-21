{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixos-bootstrap;
  worker = import ./package.nix { inherit pkgs; };
in
{
  imports = [ ./completion.nix ];
  options.services.nixos-bootstrap = {
    enable = lib.mkEnableOption "guest-owned initial NixOS adoption";
    buildTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 86400;
      description = "Guest attempt budget, independent of deployment preparation deadlines.";
    };
  };
  config = lib.mkIf cfg.enable {
    services.nixos-bootstrap-completion.enable = true;
    systemd = {
      services.nixos-bootstrap = {
        description = "Wait for prerequisites and adopt the configured NixOS flake host";
        wants = [
          "network-online.target"
          "cloud-final.service"
        ];
        after = [
          "network-online.target"
          "cloud-final.service"
          "nixos-bootstrap-complete.service"
        ];
        path = with pkgs; [
          nix
          git
          openssh
          coreutils
          systemd
          cloud-init
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${worker}/bin/nixos-bootstrap run --timeout ${toString cfg.buildTimeoutSeconds}";
          # The worker bounds its whole attempt and records timeout failures.
          TimeoutStartSec = "infinity";
          KillMode = "control-group";
          UMask = "0077";
        };
      };
      timers.nixos-bootstrap = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitInactiveSec = "30s";
        };
      };
    };
  };
}
