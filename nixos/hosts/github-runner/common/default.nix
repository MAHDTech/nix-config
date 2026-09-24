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

  ciTools =
    with pkgs;
    [
      bash
      bzip2
      coreutils
      curl
      diffutils
      file
      findutils
      gawk
      gh
      git
      git-lfs
      gnugrep
      gnused
      gnutar
      gzip
      jq
      openssh
      openssl
      patch
      procps
      rsync
      unzip
      util-linux
      xz
      zip
      zstd
    ]
    ++ [
      pkgsUnstable.devenv
      pkgsUnstable.cachix
    ];
in
{
  options.hosts.github-runner = {
    upgradeTime = lib.mkOption {
      type = lib.types.strMatching "(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]";
      default = "03:00";
      description = "Daily upgrade start time in the host timezone (HH:MM). Stagger within each runner group.";
    };

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
    ../../../system/config/services/github-runner/drain.nix
    ../../../system/config/services/nix-cache/client.nix
  ];

  config = {
    networking.hostName = name;
    environment.systemPackages = ciTools;

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
          extraPackages = ciTools ++ cfg.extraPackages;
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

    nix = {
      gc = {
        automatic = true;
        dates = lib.mkForce "02:00";
        options = lib.mkForce "--delete-older-than 3d";
        randomizedDelaySec = lib.mkForce "15m";
      };

      optimise = {
        automatic = true;
        dates = lib.mkForce [ "02:30" ];
      };

      settings = {
        trusted-users = lib.mkForce [
          "root"
          "@nix-runners"
        ];
        min-free = lib.mkForce (15 * 1024 * 1024 * 1024); # 15 GiB
        max-free = lib.mkForce (35 * 1024 * 1024 * 1024); # 35 GiB
        keep-outputs = lib.mkForce false;
        keep-derivations = lib.mkForce false;
      };
    };

    system.autoUpgrade = {
      flake = lib.mkForce "github:MAHDTech/nix-config#${name}";
      dates = lib.mkForce cfg.upgradeTime;
      randomizedDelaySec = lib.mkForce "5m";
      persistent = lib.mkForce false;
      # Compare whole generations so userspace updates also receive a reboot.
      allowReboot = lib.mkForce false;
      rebootWindow = lib.mkForce null;
    };
    systemd = {
      # OpenSSH still reads and writes the legacy last-login database.
      # Create it if missing, preserving existing login history.
      tmpfiles.rules = [ "f /var/log/lastlog 0644 root root -" ]; # cspell:ignore lastlog
      services = {
        opnix-secrets = {
          unitConfig.StartLimitIntervalSec = lib.mkForce 0;
          serviceConfig = {
            RestartPreventExitStatus = lib.mkForce [ ];
            RestartSec = lib.mkForce "5min";
          };
        };
        "github-runner-${runnerName}" = {
          wants = [ "opnix-secrets.service" ];
          after = [ "opnix-secrets.service" ];
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            # Preserve supplementary group IDs for the Nix daemon and Docker socket.
            PrivateUsers = false;
            Restart = lib.mkForce "always";
            RestartSec = "30s";
            TimeoutStartSec = "5min";
          };
        };
        nixos-upgrade = {
          environment.RUNNER_FLAKE = "github:MAHDTech/nix-config";
          environment.RUNNER_HOST = name;
          path = [
            config.system.build.nixos-rebuild
            pkgs.coreutils
            config.systemd.package
            (import ../../../system/config/services/nixos-drain/package.nix { inherit pkgs; })
          ];
          serviceConfig.EnvironmentFile = "-/etc/github-runner-bootstrap";
          serviceConfig.TimeoutStartSec = lib.mkForce (
            7200 + 2 * config.services.nixos-drain.profiles.upgrade.timeoutSeconds + 60
          );
          script = lib.mkForce (builtins.readFile ./upgrade.sh);
        };
      };
    };
  };
}
