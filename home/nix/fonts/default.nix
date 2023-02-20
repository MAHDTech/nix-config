{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
      font-manager

      cascadia-code
      corefonts
      dejavu_fonts
      jetbrains-mono
      nerdfonts
      redhat-official-fonts
      ubuntu_font_family
    ]
    ++ unstablePkgs;

  fonts.fontconfig = {enable = true;};
}
