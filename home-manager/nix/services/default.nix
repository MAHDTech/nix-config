{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./systemd.nix

    ./smartcards.nix
  ];
}
