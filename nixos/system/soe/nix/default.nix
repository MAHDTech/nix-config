{
  lib,
  pkgs,
  inputs,
  nixSettingsFlags ? [ ],
  ...
}:
{
  nix = {
    enable = true;

    package = pkgs.nixVersions.stable;

    gc = {
      automatic = true;
      dates = "Sun 19:00";
      options = "--delete-older-than 14d";
      persistent = true;
      randomizedDelaySec = "1h";
    };

    optimise = {
      automatic = true;
      dates = [ "Sun 21:00" ];
    };

    # Fleet defaults. Every key is lib.mkDefault, so any of them can be
    # overridden for a single host via `nixSettings` in nixos/hosts/default.nix
    # (applied at normal priority by mkHost) without editing this file.
    settings = lib.mapAttrs (_: lib.mkDefault) {
      cores = 0;
      max-jobs = "auto";
      require-sigs = true;
      sandbox = true;
      sandbox-fallback = false;
      system-features = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
        "uid-range"
      ];
      auto-optimise-store = true;
      auto-allocate-uids = true;
      use-cgroups = true;
      keep-outputs = true;
      keep-derivations = true;
      trusted-users = [
        "mahdtech"
      ];
      experimental-features = [
        "auto-allocate-uids"
        #"ca-derivations" # NOTE: This breaks devenv when enabled.
        "cgroups"
        "flakes"
        "nix-command"
      ];
      extra-platforms = [
        "aarch64-linux"
      ];
    };

    extraOptions = "";

    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  systemd.services.nixos-upgrade = {
    environment = {
      NIXPKGS_ALLOW_BROKEN = "0";
      NIXPKGS_ALLOW_UNFREE = "1";
      # NIXPKGS_ALLOW_INSECURE removed — use nixpkgs.config.permittedInsecurePackages instead
    };
    # Prevent indefinite hangs during unattended upgrades
    serviceConfig.TimeoutStartSec = "2h";
  };

  system = {
    autoUpgrade = {
      enable = true;

      allowReboot = true;

      operation = "boot";

      flake = "github:MAHDTech/nix-config";

      flags = [
        "--accept-flake-config"
        "--show-trace"
        # Removed: --impure (legacy, breaks reproducibility)
        # Removed: --refresh (forces full NAR info re-download, causes timeouts)
      ]
      # Host overrides from nixSettings, so unattended rebuilds are bound by
      # the same limits as interactive ones.
      ++ nixSettingsFlags;

      dates = "03:00";

      rebootWindow = {
        lower = "02:00";
        upper = "04:00";
      };
      randomizedDelaySec = "1h";
    };
  };
}
