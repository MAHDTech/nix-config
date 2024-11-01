{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  programs.dconf = {enable = true;};
}
