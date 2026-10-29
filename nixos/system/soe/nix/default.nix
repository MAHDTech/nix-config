{
  lib,
  pkgs,
  inputs,
  nixSettingsFlags ? [ ],
  ...
}:
let
  # Nix logs a warning on SQLITE_CORRUPT in its HTTP/eval caches instead of
  # recreating them, which silently disables binary cache substitution.
  healNixCache = pkgs.writeShellApplication {
    name = "heal-nix-http-cache";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sqlite
    ];
    text = ''
      shopt -s nullglob
      for db in /root/.cache/nix/*.sqlite /root/.cache/nix/eval-cache-v*/*.sqlite; do
        if out="$(sqlite3 -cmd ".timeout 5000" "file:''${db}?mode=ro" "PRAGMA integrity_check(1);" 2>&1)"; then
          rc=0
        else
          rc=$?
        fi
        if [[ $rc -eq 0 && $out != "ok" ]] || [[ $out == *"malformed"* ]] || [[ $out == *"not a database"* ]] || [[ $out == *"corrupt"* ]]; then
          echo "Removing corrupted Nix cache database: $db ($out)" >&2
          rm -f -- "$db" "''${db}-wal" "''${db}-shm"
        fi
      done
    '';
  };
in
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

    # Fleet defaults. Every key here is lib.mkDefault, so any of them can be
    # overridden for a single host via `nixSettings` in nixos/hosts/default.nix
    # (applied at normal priority by mkHost) without editing this file.
    settings = lib.mkMerge [
      (lib.mapAttrs (_: lib.mkDefault) {
        cores = 0;
        max-jobs = "auto";
        require-sigs = true;
        sandbox = true;
        sandbox-fallback = false;
        auto-optimise-store = true;
        auto-allocate-uids = true;
        use-cgroups = true;
        keep-outputs = true;
        keep-derivations = true;
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
      })

      # NOT mkDefault. nixpkgs defines both of these at normal priority in
      # nixos/modules/config/nix.nix (`trusted-users = [ "root" ]` and
      # `system-features = defaultSystemFeatures`). A mkDefault definition here
      # loses to that outright and is discarded rather than merged, which
      # silently dropped "mahdtech" and "uid-range". Defining them at normal
      # priority makes them merge with the upstream values instead.
      # Consequence: a host `nixSettings` override adds to these lists rather
      # than replacing them.
      {
        trusted-users = [ "mahdtech" ];
        system-features = [ "uid-range" ];
        nix-path = [ "nixpkgs=${inputs.nixpkgs}" ];
      }
    ];

    extraOptions = "";

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  systemd.services = {
    nix-daemon.serviceConfig.ExecStartPre = [
      "+${healNixCache}/bin/heal-nix-http-cache"
    ];

    nixos-upgrade = {
      after = [ "nix-daemon.socket" ];
      wants = [ "nix-daemon.socket" ];
      environment = {
        NIX_REMOTE = "daemon";
        NIXPKGS_ALLOW_BROKEN = "0";
        NIXPKGS_ALLOW_UNFREE = "1";
        # NIXPKGS_ALLOW_INSECURE removed — use nixpkgs.config.permittedInsecurePackages instead
      };
      # Prevent indefinite hangs during unattended upgrades
      serviceConfig = {
        ExecStartPre = [
          "+${healNixCache}/bin/heal-nix-http-cache"
        ];
        TimeoutStartSec = "2h";
      };
    };
  };

  system = {
    autoUpgrade = {
      enable = true;

      allowReboot = lib.mkDefault true;

      operation = lib.mkDefault "boot";

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

      randomizedDelaySec = "1h";
    };
  };
}
