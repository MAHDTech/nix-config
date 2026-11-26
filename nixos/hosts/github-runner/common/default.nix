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
      description = "Daily upgrade start time in the host timezone (HH:MM). Stagger across the runner fleet.";
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
    ../../../system/soe/services/envfs
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
        dates = "00:00";
        randomizedDelaySec = "2h";
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
          "kvm"
          "nix-runners"
        ];
      };
    };

    nix = {
      # CI runners exist primarily to run Nix builds; keep normal scheduling priority.
      daemonCPUSchedPolicy = "other";
      daemonIOSchedClass = "best-effort";

      gc = {
        automatic = true;
        dates = lib.mkForce "02:00";
        options = lib.mkForce "--delete-older-than 3d";
        randomizedDelaySec = lib.mkForce "2h";
      };

      optimise = {
        automatic = true;
        dates = lib.mkForce [ "04:00" ];
        randomizedDelaySec = lib.mkForce "2h";
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
        filetransfer-retry-attempts = lib.mkDefault 8;
        filetransfer-retry-delay-rate-limited = lib.mkDefault 5000;
        filetransfer-retry-max-delay = lib.mkDefault 60000;
        filetransfer-retry-jitter = lib.mkDefault true;
        tarball-ttl = lib.mkDefault 86400;
      };
    };

    system.autoUpgrade = {
      flake = lib.mkForce "github:MAHDTech/nix-config#${name}";
      dates = lib.mkForce cfg.upgradeTime;
      randomizedDelaySec = lib.mkForce "0";
      persistent = lib.mkForce false;
    };
    systemd = {
      # OpenSSH still reads and writes the legacy last-login database.
      # Create it if missing, preserving existing login history.
      tmpfiles.rules = [ "f /var/log/lastlog 0644 root root -" ]; # cspell:ignore lastlog
      services = {
        "github-runner-${runnerName}" = {
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            # Preserve supplementary group IDs for the Nix daemon and Docker socket.
            PrivateUsers = false;
            # Allow CI security tests to create owned SUID/SGID fixtures.
            RestrictSUIDSGID = false;
            Restart = lib.mkForce "always";
            RestartSec = "5s";
            TimeoutStartSec = "5min";
          };
        };
      };
    };
  };
}
