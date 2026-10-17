{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.clamav-notify;
  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
in
{
  options.services.clamav-notify = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the ClamAV notification daemon, VirusEvent hook, and TUI inbox.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = import ./package.nix { inherit pkgs; };
      defaultText = lib.literalExpression "import ./package.nix { inherit pkgs; }";
      description = "The clamav-notify package to use.";
    };

    since = lib.mkOption {
      type = lib.types.str;
      default = "-7 days";
      description = "Initial journal lookback window when no saved cursor exists.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.clamav.daemon.settings = {
      VirusEvent = "${cfg.package}/bin/clamav-notify emit-event";
    };

    users.groups.systemd-journal.members = lib.mapAttrsToList (_: u: u.name) normalUsers;

    systemd.user.services.clamav-notify = {
      description = "ClamAV desktop notification and inbox daemon";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/clamav-notify daemon --since=${lib.escapeShellArg cfg.since}";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
