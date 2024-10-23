{pkgs, ...}: {
  home.packages = with pkgs; [
    font-manager
    fontconfig

    corefonts
    dejavu_fonts
    dina-font
    emojione
    fira-code
    fira-code-symbols
    jetbrains-mono
    liberation_ttf
    nerd-font-patcher
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
  #++ unstablePkgs;

  fonts = {
    fontconfig = {
      enable = true;
    };
  };
}
