{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  # Define imports
  imports = [
    # Home Manager configuration
    ./nix/home-manager

    # User environment config
    ./nix/user

    # Files and directories
    ./nix/files

    # Font management
    ./nix/fonts

    # Modules
    ./nix/modules

    # Custom derivations
    ./nix/derivations

    # Secrets
    ./nix/secrets

    # Packages
    ./nix/packages

    # Programs
    ./nix/programs

    # Services
    ./nix/services
  ];
}
