{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.autorandr = {enable = false;};
}
