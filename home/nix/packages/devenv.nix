{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  unstablePkgs = with pkgsUnstable; [
    devenv
  ];
in
{

  home.packages =
    with pkgs;
    [
      cachix
      #devenv
      secretspec
    ]
    ++ unstablePkgs;
}
