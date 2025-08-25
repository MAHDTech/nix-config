{
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    zafiro-icons
  ];

  gtk = {
    cursorTheme = {
      name = "Pop";
    };

    iconTheme = {
      name = "Zafiro-icons-Light";
    };
  };
}
