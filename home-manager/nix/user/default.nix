{config, ...}: {
  home = {
    sessionVariables = {
      # Allow unfree packages.
      NIXPKGS_ALLOW_UNFREE = 1;

      # Enable wayland support in electron apps.
      NIXOS_OZONE_WL = "1";

      # This location is read by direnv to change into the flake dir to launch devShells
      #DEVENV_DEVSHELLS_HOME = "${config.home.homeDirectory}/Projects/GitHub/MAHDTech/nix-config";
      DEVENV_DEVSHELLS_HOME = "/mnt/projects/github/MAHDTech/nix-config";

      # HACK: Until 23.05 is released
      #NIXPKGS_ALLOW_INSECURE = "1";
    };
  };
}
