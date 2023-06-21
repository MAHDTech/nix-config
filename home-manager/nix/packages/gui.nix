{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    brave
    lapce
    logseq
    microsoft-edge
  ];
in {
  home.packages = with pkgs;
    [
      _1password
      _1password-gui

      gtk3

      inkscape
      libreoffice
      pinta

      tilix

      gparted
    ]
    ++ unstablePkgs;
}
