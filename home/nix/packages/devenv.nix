{
  inputs,
  pkgs,
  isNixosHM ? false,
  ...
}:
let
  targetSystem = pkgs.stdenv.hostPlatform.system;
  devenv-nixpkgs = inputs.devenv-nixpkgs.legacyPackages.${targetSystem};

  # Disable devenv packages inside NixOS Home Manager on aarch64 to prevent
  # cross-compilation IFD bootstrap failures on AMD64. It remains fully enabled
  # in standalone Home Manager (on your ARM64 dev station) and native AMD64 hosts!
  devenvEnabled = !(isNixosHM && targetSystem == "aarch64-linux");

  devenvPkgs =
    if devenvEnabled then
      [
        devenv-nixpkgs.cachix
        devenv-nixpkgs.devenv
        devenv-nixpkgs.secretspec
      ]
    else
      [ ];

in
{
  home.packages = devenvPkgs;
}
