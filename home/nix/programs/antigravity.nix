{
  inputs,
  pkgs,
  ...
}:
let

  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  unstablePkgs = with pkgsUnstable; [
    antigravity-fhs
  ];
in
{

  home.packages = unstablePkgs;
  #  with pkgs;
  #  [
  #    #antigravity-fhs
  #  ]
  #  ++ unstablePkgs;
}
