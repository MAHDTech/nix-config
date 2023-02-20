{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  home = {
    sessionVariables = {
      # Allow unfree packages.
      NIXPKGS_ALLOW_UNFREE = 1;

      # Enable wayland support in electron apps.
      NIXOS_OZONE_WL = "1";
    };
  };
}
