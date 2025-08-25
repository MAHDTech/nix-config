{
  imports = [
    # General scripts.
    ./scripts.nix

    # Storj related scripts.
    ./storj.nix

    # Setup Hyprland Workspaces
    ./setup-workspaces.nix

    # Hyprland misc scripts
    ./hyprland.nix

    # Sync projects.
    ./sync-projects.nix
  ];
}
