{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  # Using seahorse from home-manager instead.
  programs.seahorse = {enable = false;};
}
