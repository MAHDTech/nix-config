{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  # https://nixos.wiki/wiki/Fonts

  fonts = {
    packages = with pkgs; [
      corefonts
      dejavu_fonts
      dina-font
      emojione
      fira-code
      fira-code-symbols
      jetbrains-mono
      liberation_ttf
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      openmoji-color
      roboto
      roboto-mono
      source-code-pro
      source-sans-pro
      source-serif-pro
      ttf_bitstream_vera
      twitter-color-emoji
      ubuntu_font_family

      # Nerd fonts
      (nerdfonts.override {
        fonts = [
          "CascadiaCode"
          "DejaVuSansMono"
          "DroidSansMono"
          "FiraCode"
          "FiraCode"
          "FiraMono"
          "Go-Mono"
          "Hack"
          "Inconsolata"
          "Iosevka"
          "JetBrainsMono"
          "Mononoki"
          "Noto"
          "RobotoMono"
          "SourceCodePro"
          "SpaceMono"
          "Ubuntu"
          "UbuntuMono"
          "VictorMono"
        ];
      })
    ];

    fontDir = {
      enable = true;
    };

    fontconfig = {
      defaultFonts = {
        monospace = [
          "Ubuntu Mono Regular"
          "UbuntuMono Nerd Font Regular"
          "Noto Sans Mono"
          "Noto Sans Mono Regular"
          "DejaVu Sans Mono Book"
          "Source Code Pro Regular"
        ];

        sansSerif = [
          "Metropolis"
          "Metropolis Regular"
          "Ubuntu Regular"
          "Ubuntu Nerd Font Book"
          "Noto Sans"
          "DejaVu Sans Book"
          "Source Sans Pro"
        ];

        serif = [
          "Metropolis"
          "Metropolis Regular"
          "Ubuntu Regular"
          "Ubuntu Nerd Font Book"
          "Noto Serif"
          "DejaVu Serif Book"
          "Source Serif Pro"
        ];
      };
    };
  };
}
