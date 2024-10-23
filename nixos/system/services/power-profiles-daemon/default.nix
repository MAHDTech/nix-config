{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  # Using Power-Profiles Daemon as it works with COSMIC.
  # But TLP works better :/
  services.power-profiles-daemon = {enable = false;};
}
