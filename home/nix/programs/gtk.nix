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

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    cursorTheme = {
      name = "Pop";
    };

    iconTheme = {
      name = "Zafiro-icons-Light";
    };
  };
}
