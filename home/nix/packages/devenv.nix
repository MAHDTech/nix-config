{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  unstablePkgs = with pkgsUnstable; [
    cachix
    devenv
    secretspec
  ];
in
{

  home.packages = unstablePkgs;
  #with pkgs;
  #[
  #cachix
  #devenv
  #secretspec
  #]
  #++ unstablePkgs;
}
