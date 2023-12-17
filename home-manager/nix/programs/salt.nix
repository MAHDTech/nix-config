{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
# NOTE: Moved to a python pip package.
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  #home.packages = with pkgs; [] ++ unstablePkgs;
}
