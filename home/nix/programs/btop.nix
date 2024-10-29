{pkgs, ...}: {
  home.packages = with pkgs; [];

  programs.btop = {
    enable = true;
    catppuccin = {
      enable = true;
      flavor = "mocha";
    };
  };
}
