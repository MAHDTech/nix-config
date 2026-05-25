{
  inputs,
  pkgs,
  isNixosHM ? false,
  ...
}:
let
  targetSystem = pkgs.stdenv.hostPlatform.system;

  # Disable devenv packages inside NixOS Home Manager on aarch64 to prevent
  # cross-compilation IFD bootstrap failures on AMD64. It remains fully enabled
  # in standalone Home Manager (on your ARM64 dev station) and native AMD64 hosts!
  devenvEnabled = !(isNixosHM && targetSystem == "aarch64-linux");

  devenvPkgs =
    if devenvEnabled then
      [
        pkgs.cachix
        inputs.devenv.packages.${targetSystem}.devenv
        inputs.nixpkgs-unstable.legacyPackages.${targetSystem}.secretspec
      ]
    else
      [ ];

in
{
  home.packages = devenvPkgs;
}
