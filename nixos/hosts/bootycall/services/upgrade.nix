{
  nixSettingsFlags ? [ ],
  ...
}:
{
  nix = {
    # NOTE: cores/max-jobs live in this host's `nixSettings` in
    # nixos/hosts/default.nix; mkHost applies them to nix.settings and the
    # autoUpgrade flags below pass the same limits to unattended rebuilds.
    settings = {
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
    ]
    ++ nixSettingsFlags;
  };
}
