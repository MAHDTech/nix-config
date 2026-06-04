{
  inputs,
  pkgs,
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

    settings = {
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
        "ca-derivations"
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
      NIXPKGS_ALLOW_INSECURE = "1";
      NIXPKGS_ALLOW_UNFREE = "1";
    };
  };

  system = {
    autoUpgrade = {
      enable = true;

      allowReboot = true;

      operation = "boot";

      flake = "github:MAHDTech/nix-config";

      flags = [
        "--accept-flake-config"
        "--impure"
        "--refresh"
        "--show-trace"
        "--verbose"
      ];

      dates = "03:00";

      rebootWindow = {
        lower = "02:00";
        upper = "04:00";
      };
      randomizedDelaySec = "1h";
    };
  };
}
