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

    # Emoji Fonts
    joypixels
    twitter-color-emoji
    font-awesome

    # Microsoft fonts
    vista-fonts
    cascadia-code

    # Popular fonts
    ubuntu-classic
    source-code-pro
    source-sans
    source-serif

    # VMware
    clarity-city

    # Nerd Fonts
    nerd-fonts.arimo
    nerd-fonts.commit-mono
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.fira-code
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
    nerd-fonts.ubuntu-sans
    nerd-fonts.victor-mono
  ];

  fonts = {
    fontconfig = {
      enable = false;
      defaultFonts = {
        monospace = [
          "VictorMono Nerd Font Mono"
          "JetBrainsMono Nerd Font Regular"
          "FiraCode Nerd Font Mono"
          "SauceCodePro Nerd Font Mono"
          "Cascadia Code NF"
          "UbuntuMono Nerd Font Mono"
        ];
        sansSerif = [
          "Clarity City"
          "Ubuntu Nerd Font"
          "Hack Nerd Font"
          "FreeSans"
          "Liberation Sans"
          "DejaVu Sans"
        ];
        serif = [
          "Noto Serif"
          "DejaVu Serif"
          "FreeSerif"
          "Liberation Serif"
        ];
        emoji = [
          "JoyPixels"
          "Twitter Color Emoji"
          "Noto Color Emoji"
        ];
      };
    };
  };
}
