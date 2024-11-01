{pkgs, ...}: {
  # Darling is the macOS compatibility layer for Linux.

  imports = [
  ];

  environment.systemPackages = with pkgs; [
    darling-dmg
  ];

  programs.darling = {
    enable = true;
    package = pkgs.darling;
  };
}
