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

  # The shared upgrade module stages boot generations, drains and reboots.
  system.autoUpgrade = {
    enable = true;
    flake = "github:MAHDTech/nix-config";
    dates = "03:00";
    flags = [
      "--accept-flake-config"
      "--show-trace"
    ]
    ++ nixSettingsFlags;
  };
}
