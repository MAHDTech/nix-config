{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  programs.nm-applet = {enable = true;};
}
