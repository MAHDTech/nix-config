{
  inputs,
  pkgs,
  ...
}:
let

  inherit (inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system})
    cachix
    devenv
    secretspec
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
