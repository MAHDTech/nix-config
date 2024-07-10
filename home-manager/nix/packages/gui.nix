{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    #lapce
    #logseq
  ];
in {
  home.packages = with pkgs;
    [
      # 1Password needs the Nix module so only works on NixOS.
      # On Debian, use the deb package.
      #_1password
      #_1password-gui

      # Shared GTK is needed for GUI apps like VSCode
      gtk3

      lapce

      logseq

      #inkscape
      #libreoffice
      #pinta

      #tilix

      #insync

      #gparted

      #discord
      #signal-desktop
      #telegram-desktop

      #brave
      #google-chrome
      #microsoft-edge

      #trezor-suite
      #ledger-live-desktop

      #vlc

      #libsForQt5.kolourpaint

      # JetBrains
      #jetbrains.rust-rover
      #(pkgs.jetbrains.plugins.addPlugins pkgs.jetbrains.rust-rover ["github-copilot"])
      #jetbrains-toolbox
    ]
    ++ unstablePkgs;
}
