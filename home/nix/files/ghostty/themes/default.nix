{ config, ... }:
{
  home.file = {
    "ghostty-theme-tars-dark" = {
      target = "${config.home.homeDirectory}/.config/ghostty/themes/TARS Dark";
      source = ./tars_dark;
    };
    "ghostty-theme-tars-light" = {
      target = "${config.home.homeDirectory}/.config/ghostty/themes/TARS Light";
      source = ./tars_light;
    };
    "ghostty-theme-tars-synthwave" = {
      target = "${config.home.homeDirectory}/.config/ghostty/themes/TARS Synthwave";
      source = ./tars_synthwave;
    };
    "ghostty-theme-tars-blue" = {
      target = "${config.home.homeDirectory}/.config/ghostty/themes/TARS Blue";
      source = ./tars_blue;
    };
  };
}
