{config, ...}: {
  home = {
    sessionVariables = {
      # Allow unfree packages.
      NIXPKGS_ALLOW_UNFREE = 1;

      # Enable wayland support in electron apps.
      NIXOS_OZONE_WL = "1";

      # Dotfiles config
      DOTFILES_HOME_CONFIG = "${config.home.homeDirectory}/dotfiles";
      DOTFILES_NIX_CONFIG = "$/boot/nix/nix-config";

      # This location is read by direnv to change into the flake dir to launch devShells
      DEVENV_DEVSHELLS_HOME = "${config.home.homeDirectory}/dotfiles";

      # Wakatime Home Directory
      WAKATIME_HOME = "${config.home.homeDirectory}/.wakatime";
    };
  };
}
