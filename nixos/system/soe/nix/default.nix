{
  inputs,
  pkgs,
  ...
}:
{
  nix = {
    enable = true;

    package = pkgs.nixStable;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
      randomizedDelaySec = "1h";
    };

    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    settings = {
      max-jobs = "auto";
      require-sigs = true;
      sandbox = true;
      sandbox-fallback = false;
      system-features = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      auto-optimise-store = true;
      keep-outputs = true;
      keep-derivations = true;
      trusted-users = [
        "root"
        "mahdtech"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
        "ca-derivations"
        "auto-allocate-uids"
      ];
      extra-platforms = [
        "aarch64-linux"
      ];
    };

    extraOptions = '''';

    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  systemd.services.nixos-upgrade = {
    environment = {
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

      dates = "daily";

      rebootWindow = {
        lower = "02:00";
        upper = "04:00";
      };
      randomizedDelaySec = "1h";
    };
  };
}
