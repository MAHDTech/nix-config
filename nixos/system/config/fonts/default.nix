{ pkgs, ... }:
{
  # https://nixos.wiki/wiki/Fonts
  fonts = {
    packages = with pkgs; [
      # Font utilities
      font-manager
      fontconfig

      # Core fonts
      corefonts
      dejavu_fonts
      liberation_ttf
      noto-fonts

      # Emoji fonts
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

    fontDir = {
      enable = true;
      decompressFonts = true;
    };

    fontconfig = {
      enable = true;
      useEmbeddedBitmaps = true;
      defaultFonts = {
        monospace = [
          "JetBrainsMono Nerd Font Regular"
          "VictorMono Nerd Font Mono"
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
          "Noto Color Emoji"
        ];
      };
    };
  };
}
