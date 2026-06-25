_: {
  nix = {
    # Low-power settings to prevent OOM/overheating during builds
    settings = {
      cores = 4; # Use only 4 of the 8 low-power Cortex-A53 cores
      max-jobs = 1; # Run builds sequentially
      trusted-users = [ "cooper" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Run GC weekly
    gc = {
      automatic = true;
      dates = "Sun 03:00";
      options = "--delete-older-than 10d";
    };

    # Run store optimization weekly
    optimise = {
      automatic = true;
      dates = [ "Sun 04:00" ];
    };
  };

  # Enable NixOS daily auto-upgrades in-place (no reboot)
  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # Do not reboot automatically (halts the CPU)
    operation = "switch"; # Apply configuration live in-place
    flake = "github:MAHDTech/nix-config";
    dates = "03:00";
    flags = [
      "--accept-flake-config"
      "--show-trace"
    ];
  };
}
