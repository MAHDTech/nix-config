{
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    zafiro-icons
  ];

  gtk = {
    enable = true;

    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    iconTheme = {
      name = "Zafiro-icons-Dark";
    };
  };
}
