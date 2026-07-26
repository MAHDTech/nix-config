{
  pkgsUnstable,
  ...
}:
let
  # To use the devenv-nixpkgs input instead, add `inputs,` and `pkgs,` back to
  # the arguments above:
  #devenv-nixpkgs = inputs.devenv-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};

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
