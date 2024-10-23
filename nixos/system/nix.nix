{
  inputs,
  pkgs,
  ...
}: {
  nix = {
    enable = true;

    package = pkgs.nixStable;
    #package = pkgs.nixUnstable;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise = {
      automatic = true;
      dates = ["weekly"];
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
      trusted-users = ["root" "mahdtech"];
      experimental-features = [
        "nix-command"
        "flakes"
        "ca-derivations"
        "auto-allocate-uids"
        #"configurable-impure-env"
      ];
    };

    extraOptions = ''
    '';

    nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  system.autoUpgrade = {
    enable = true;

    allowReboot = true;

    operation = "boot";

    flake = "/boot/nixos/nix-config";

    flags = ["--impure" "--update-input" "nixpkgs" "--commit-lock-file"];

    dates = "weekly";
  };
}
