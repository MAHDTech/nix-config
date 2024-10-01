{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  # NOTE: cosmic packages now pulled from nixos-cosmic flake.

  hardware.system76.enableAll = true;

}