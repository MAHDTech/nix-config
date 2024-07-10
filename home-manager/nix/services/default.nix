{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./gnome-keyring.nix
    ./systemd.nix
    ./smartcards.nix
  ];
}
