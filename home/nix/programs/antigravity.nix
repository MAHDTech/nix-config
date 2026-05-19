{
  inputs,
  pkgs,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

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
