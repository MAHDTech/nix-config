{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  name,
  ...
}:
let
  cfg = config.hosts.github-runner;
  runnerName = "${name}-enterprise-mahdtech";
  jobPackages =
    with pkgs;
    [
      nodejs_24
      python3
      gnumake
      gcc
      pkg-config
      unzip
      zip
    ]
    ++ [
      pkgsUnstable.devenv
      pkgsUnstable.cachix
    ];
in
{
  options.hosts.github-runner = {
    runnerGroup = lib.mkOption {
      type = lib.types.str;
      description = "GitHub Actions runner group for registration.";
    };

    tokenReference = lib.mkOption {
      type = lib.types.str;
      description = "1Password secret reference for the runner registration PAT.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/enterprises/MAHDTech";
      description = "Enterprise or organisation registration URL.";
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional labels to attach to this runner.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to make available in the runner environment.";
    };
  };

  imports = [
    ./base.nix
    ../../../system/soe/nix
    ../../../system/soe/secrets/opnix.nix
    ../../../system/soe/programs/nix-ld
    ../../../system/config/services/github-runner
  ];

  config = {
    networking.hostName = name;
    environment.systemPackages = jobPackages ++ [
      pkgs.git
      pkgs.jq
    ];

    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "daily";
        flags = [ "--all" ];
      };
      logDriver = "journald";
    };
    services = {
      cloud-init.settings.preserve_hostname = true;
      journald.settings.Journal.SystemMaxUse = "1G";
      github-runner-fleet = {
        enable = true;
        inherit (cfg) tokenReference;
        runners.enterprise = {
          inherit (cfg) url runnerGroup extraLabels;
          extraPackages = jobPackages ++ cfg.extraPackages;
        };
      };
      github-runners.${runnerName} = {
        user = "github-runner";
        group = "github-runner";
      };
    };

    users = {
      groups = {
        github-runner = { };
        nix-runners = { };
      };
      # Nix resolves trusted group membership through the user database.
      users.github-runner = {
        isSystemUser = true;
        group = "github-runner";
        extraGroups = [
          "docker"
          "nix-runners"
        ];
      };
    };
    nix.settings.trusted-users = lib.mkForce [
      "root"
      "@nix-runners"
    ];

    system.autoUpgrade = {
      flake = lib.mkForce "github:MAHDTech/nix-config#${name}";
      dates = lib.mkForce "03:00";
      randomizedDelaySec = lib.mkForce "30m";
      # The upstream reboot check only detects kernel changes. Reboot after
      # every successful boot-generation update so userspace changes apply too.
      allowReboot = lib.mkForce false;
      rebootWindow = lib.mkForce null;
    };
    systemd = {
      services = {
        opnix-secrets = {
          unitConfig.StartLimitIntervalSec = lib.mkForce 0;
          serviceConfig = {
            RestartPreventExitStatus = lib.mkForce [ ];
            RestartSec = lib.mkForce "5min";
          };
        };
        "github-runner-${runnerName}" = {
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            # Preserve supplementary group IDs for the Nix daemon and Docker socket.
            PrivateUsers = false;
            Restart = lib.mkForce "always";
            RestartSec = "30s";
          };
        };
        nixos-upgrade = {
          environment.RUNNER_FLAKE = "github:MAHDTech/nix-config";
          serviceConfig.EnvironmentFile = "-/etc/github-runner-bootstrap";
          script = lib.mkForce ''
            ${config.system.build.nixos-rebuild}/bin/nixos-rebuild boot \
              --flake "$RUNNER_FLAKE#${name}" --accept-flake-config --show-trace --refresh
          '';
          postStart = "${config.systemd.package}/bin/shutdown -r +1";
        };
      };
      timers.nixos-upgrade.timerConfig.Persistent = true;
    };
  };
}
