{
  imports = [
    ./appearance.nix
    ./compositor.nix
    ./idle.nix
    ./panels.nix
    ./shortcuts.nix
    ./wallpapers.nix
  ];

  wayland.desktopManager.cosmic = {
    enable = true;
    wallpapers = [ ];
  };
}
