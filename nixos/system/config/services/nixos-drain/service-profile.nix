{
  name,
  units,
  enable ? true,
  timeoutSeconds ? 900,
}:
{ lib, pkgs, ... }:
let
  state = "/run/nixos-drain/${name}";
  handler = pkgs.writeShellApplication {
    name = "${name}-drain";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = ''
      export SERVICE_DRAIN_STATE=${lib.escapeShellArg state}
      exec bash ${./service-profile.sh} "$@" ${lib.escapeShellArgs units}
    '';
  };
  profile = {
    inherit timeoutSeconds;
    script = "${handler}/bin/${name}-drain drain";
    cancelScript = "${handler}/bin/${name}-drain cancel";
  };
in
{
  imports = [ ./. ];
  config = lib.mkIf enable {
    services.nixos-drain = {
      enable = true;
      profiles = {
        upgrade = profile // {
          cancelOnFailure = true;
        };
        maintenance = profile;
        destroy = profile;
      };
    };
    systemd.services = builtins.listToAttrs (
      map (unit: {
        name = lib.removeSuffix ".service" unit;
        value.serviceConfig.ExecCondition = [
          "${pkgs.coreutils}/bin/test ! -e ${state}/blocked"
        ];
      }) (builtins.filter (lib.hasSuffix ".service") units)
    );
  };
}
