{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    brave
    #lapce
    logseq
  ];
in {
  home.packages = with pkgs;
    [
      _1password
      _1password-gui

      #microsoft-edge

      gtk3

      inkscape
      libreoffice
      pinta
    ]
    ++ unstablePkgs;
}
