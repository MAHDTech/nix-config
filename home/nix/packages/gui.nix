{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    brave
  ];
in {
  home.packages = with pkgs;
    [
      _1password
      _1password-gui

      #gtk3

      #logseq

      #inkscape
      #libreoffice
      #pinta
    ]
    ++ unstablePkgs;
}
