{pkgs, ...}: {
  home.packages = with pkgs; [];

  programs.neovim = {
    enable = false;

    catppuccin = {
      enable = true;
      flavor = "mocha";
    };
  };
}
