{
  imports = [
    # Common tooling across all projects
    ./tools.nix

    # Devenv and Cachix
    ./devenv.nix

    # Custom packages
    ./custom
  ];
}
