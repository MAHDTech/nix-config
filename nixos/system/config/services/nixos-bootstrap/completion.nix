{
  config,
  lib,
  pkgs,
  ...
}:
let
  worker = import ./package.nix { inherit pkgs; };
in
{
  options.services.nixos-bootstrap-completion.enable = lib.mkEnableOption "guest-owned bootstrap completion";
  config = lib.mkIf config.services.nixos-bootstrap-completion.enable {
    environment.systemPackages = [ worker ];
    systemd = {
      tmpfiles.rules = [
        "d /etc/nixos-bootstrap 0700 root root -"
        "d /var/lib/nixos-bootstrap 0700 root root -"
      ];
      services.nixos-bootstrap-complete = {
        description = "Verify first boot into the intended NixOS system";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.ConditionPathExists = "/var/lib/nixos-bootstrap/status.json";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${worker}/bin/nixos-bootstrap complete";
          UMask = "0077";
        };
      };
    };
  };
}
