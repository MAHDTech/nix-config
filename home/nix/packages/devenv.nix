{
  inputs,
  pkgs,
  ...
}:
let

  inherit (inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system})
    cachix
    secretspec
    ;

  inherit (inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system})
    devenv
    ;

  devenvPkgs = [
    cachix
    devenv
    secretspec
  ];

in
{
  home.packages = devenvPkgs;
}
