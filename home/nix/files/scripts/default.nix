{
  imports = [
    # General scripts.
    ./scripts.nix

    # Wallpaper rotation.
    ./random-wallpaper.nix

    # Storj related scripts.
    ./storj.nix

    # Setup Hyprland Workspaces
    ./setup-workspaces.nix

    # Sync projects.
    ./sync-projects.nix
  ];
}
