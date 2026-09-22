{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixos-drain;
  package = import ./package.nix { inherit pkgs; };
  profileType = lib.types.submodule {
    options = {
      script = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Drain commands. An empty script only announces the profile with wall.";
      };
      cancelScript = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands to undo a drain, including a partially completed or failed drain.";
      };
      timeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = cfg.timeoutSeconds;
        defaultText = lib.literalExpression "config.services.nixos-drain.timeoutSeconds";
        description = "Maximum duration of the drain script, or of cancellation cleanup.";
      };
    };
  };
  profiles = lib.mapAttrs (name: profile: {
    inherit (profile) timeoutSeconds;
    notificationOnly = profile.script == "";
    script = pkgs.writeShellScript "nixos-drain-${name}" ''
      set -euo pipefail
      ${profile.script}
    '';
    cancelScript = pkgs.writeShellScript "nixos-drain-${name}-cancel" ''
      set -euo pipefail
      ${profile.cancelScript}
    '';
  }) cfg.profiles;
in
{
  options.services.nixos-drain = {
    enable = lib.mkEnableOption "host draining through named application scripts";
    timeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3600;
      description = "Default profile timeout in seconds.";
    };
    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      description = "Named drain profiles. Scripts run as root with NIXOS_DRAIN_PROFILE set.";
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (name: builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" name != null) (
          builtins.attrNames cfg.profiles
        );
        message = "nixos-drain profile names must contain only letters, digits, underscores and hyphens.";
      }
    ];
    services.nixos-drain.profiles = {
      upgrade = { };
      destroy = { };
      maintenance = { };
    };
    environment.systemPackages = [ package ];
    environment.etc."nixos-drain/config.json".text = builtins.toJSON profiles;
    systemd.tmpfiles.rules = [ "d /run/nixos-drain 0755 root root -" ];
  };
}
