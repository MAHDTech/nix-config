{
  inputs,
  pkgs,
  ...
}:
let
  targetSystem = pkgs.stdenv.hostPlatform.system;
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${targetSystem};
  #devenv-nixpkgs = inputs.devenv-nixpkgs.legacyPackages.${targetSystem};

  devenvPkgsUnstable = with pkgsUnstable; [
    cachix
    devenv
    secretspec
  ];

  #devenvPkgs = with devenv-nixpkgs; [
  #  cachix
  #  devenv
  #  secretspec
  #];

in
{
  #home.packages = devenvPkgs;
  home.packages = devenvPkgsUnstable;
}
