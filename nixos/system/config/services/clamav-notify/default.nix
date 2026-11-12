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

    remindInterval = lib.mkOption {
      type = lib.types.str;
      default = "4h";
      description = "Interval to repeat summary toast notifications while unresolved OPEN alerts remain (set to 'off' to disable).";
    };

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "cosmic-term";
      description = "Terminal emulator executable launched with '-e clamav-notify' when clicking 'Open Inbox' on a toast.";
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
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      path = [ "/run/current-system/sw" ];
      environment = {
        CLAMAV_NOTIFY_TERMINAL_BIN = cfg.terminal;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/clamav-notify daemon --since=${lib.escapeShellArg cfg.since} --remind-interval=${lib.escapeShellArg cfg.remindInterval}";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
