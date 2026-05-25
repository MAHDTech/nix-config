{
  inputs,
  pkgs,
  ...
}:
let

  isX86 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  devenvPkgs =
    if isX86 then
      [
        inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.cachix
        inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
        inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.secretspec
      ]
    else
      [ ];

in
{
  home.packages = devenvPkgs;
}
