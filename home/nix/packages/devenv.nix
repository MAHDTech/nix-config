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
    # NOTE: `secretspec` removed — devenv 2.2.0 vendors its own bin/secretspec,
    # and listing both made home.packages fail to build:
    #   pkgs.buildEnv error: two given paths contain a conflicting subpath:
    #     .../secretspec-0.17.0/bin/secretspec
    #     .../devenv-2.2.0/bin/secretspec
    # Re-add it here if devenv ever stops bundling it.
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
