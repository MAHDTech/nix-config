{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Font utilities
    font-manager
    fontconfig

    # Core fonts
    corefonts
    dejavu_fonts
    liberation_ttf
    noto-fonts
    emojione
    twitter-color-emoji
    font-awesome

    # Microsoft fonts
    vistafonts
    cascadia-code

    # Popular fonts
    ubuntu_font_family
    source-code-pro
    source-sans
    source-serif

    # Nerd Fonts
    nerd-fonts.fira-code
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.fira-mono
    nerd-fonts.go-mono
    nerd-fonts.hack
    nerd-fonts.inconsolata
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.mononoki
    nerd-fonts.noto
    nerd-fonts.roboto-mono
    nerd-fonts.sauce-code-pro
    nerd-fonts.space-mono
    nerd-fonts.ubuntu
    nerd-fonts.ubuntu-mono
    nerd-fonts.victor-mono
  ];

  fonts = {
    fontconfig = {
      enable = true;
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
