{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
      _1password
      _1password-gui

      brave

      gtk3

      logseq

      inkscape
      libreoffice
      pinta
    ]
    ++ unstablePkgs;
}
