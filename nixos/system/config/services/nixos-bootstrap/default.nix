{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixos-bootstrap;
  worker = ./worker.py;
in
{
  options.services.nixos-bootstrap.enable = lib.mkEnableOption "one-time generic NixOS adoption";
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.python3 ];
    # Keep the protocol client available after the final configuration removes
    # this module, so the controller can verify the reboot and record completion.
    systemd = {
      tmpfiles.rules = [
        "d /var/lib/nixos-bootstrap 0700 root root -"
        "C /var/lib/nixos-bootstrap/worker.py 0700 root root - ${worker}"
      ];
      services = {
        nixos-bootstrap = {
          description = "Adopt the selected NixOS flake host";
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "cloud-final.service"
          ];
          path = with pkgs; [
            nix
            git
            openssh
            coreutils
            systemd
            cloud-init
          ];
          unitConfig.ConditionPathExists = [
            "/var/lib/nixos-bootstrap/release.json"
            "!/var/lib/nixos-bootstrap/complete.json"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.python3}/bin/python3 ${worker} build";
            TimeoutStartSec = "1d";
            KillMode = "control-group";
            UMask = "0077";
          };
        };
        # A timer avoids a permanently present malformed release causing a path
        # activation loop. No waiting job blocks cloud-init or multi-user.target.
        nixos-bootstrap-prepare = {
          description = "Prepare automatic NixOS adoption when explicitly configured";
          wantedBy = [ "multi-user.target" ];
          wants = [ "cloud-final.service" ];
          after = [ "cloud-final.service" ];
          path = [ pkgs.systemd ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.python3}/bin/python3 ${worker} prepare";
            UMask = "0077";
          };
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
