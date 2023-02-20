{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  programs.fzf = {
    enable = true;

    enableBashIntegration = true;
  };
}
