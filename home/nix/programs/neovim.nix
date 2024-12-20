{pkgs, ...}: {
  home.packages = with pkgs; [];

  programs.neovim = {
    enable = false;
  };
}
