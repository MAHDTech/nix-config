{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    walker
  ];

  xdg = {
    configFile = {
      "walker-config" = {
        source = ./config.toml;
        target = "walker/config.toml";
      };

      "walker-themes-custom-css" = {
        source = ./themes/custom.css;
        target = "walker/themes/custom.css";
      };

      "walker-themes-custom-toml" = {
        source = ./themes/custom.toml;
        target = "walker/themes/custom.toml";
      };

      "walker-themes-custom-window-toml" = {
        source = ./themes/custom_window.toml;
        target = "walker/themes/custom_window.toml";
      };
    };
  };
}
