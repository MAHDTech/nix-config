{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  programs.command-not-found = {enable = true;};
}
