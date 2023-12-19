{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    #brave
    #lapce
    #logseq
    #microsoft-edge
  ];
in {
  home.packages = with pkgs;
    [
      _1password
      _1password-gui

      # Shared GTK is needed for GUI apps like VSCode
      gtk3

      #inkscape
      #libreoffice
      #pinta

      #tilix

      gparted

      discord

      brave
      google-chrome
      #microsoft-edge

      trezor-suite
      ledger-live-desktop
    ]
    ++ unstablePkgs;
}
