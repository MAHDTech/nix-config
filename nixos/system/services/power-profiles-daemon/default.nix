{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.power-profiles-daemon = {enable = true;};
}
