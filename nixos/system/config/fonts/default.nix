{pkgs, ...}: {
  # https://nixos.wiki/wiki/Fonts

  fonts = {
    packages = with pkgs; [
      # Core fonts
      corefonts
      emojione
      twitter-color-emoji

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
      enable = true;
      useEmbeddedBitmaps = true;
      defaultFonts = {
        monospace = [
          "JetBrainsMono Nerd Font Regular"
          "Ubuntu Mono Regular"
          "UbuntuMono Nerd Font Regular"
          "Noto Sans Mono"
          "Noto Sans Mono Regular"
          "DejaVu Sans Mono Book"
          "Source Code Pro Regular"
        ];
        sansSerif = [
          "JetBrainsMono Nerd Font Regular"
          "Metropolis"
          "Metropolis Regular"
          "Ubuntu Regular"
          "Ubuntu Nerd Font Book"
          "Noto Sans"
          "DejaVu Sans Book"
          "Source Sans Pro"
        ];
        serif = [
          "JetBrainsMono Nerd Font Regular"
          "Metropolis"
          "Metropolis Regular"
          "Ubuntu Regular"
          "Ubuntu Nerd Font Book"
          "Noto Serif"
          "DejaVu Serif Book"
          "Source Serif Pro"
        ];
        emoji = [
          "EmojiOne Color"
          "Twitter Color Emoji"
          "Noto Color Emoji"
        ];
      };
    };
  };
}
