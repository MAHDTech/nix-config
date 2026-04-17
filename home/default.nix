{
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
