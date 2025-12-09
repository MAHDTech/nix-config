{
  inputs,
  pkgs,
  ...
}:
let
  _pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  #unstablePkgs = with pkgsUnstable; [
  #devenv
  #];
in
{

  home.packages = with pkgs; [
    cachix
    devenv
    secretspec
  ];
  #++ unstablePkgs;
}
