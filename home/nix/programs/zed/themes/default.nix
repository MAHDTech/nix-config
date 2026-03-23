{ lib, ... }:
{
  xdg.configFile = {
    "zed_theme_tars_dark" = {
      enable = true;
      target = "zed/themes/tars_dark.json";
      source = ./tars_dark.json;
    };
    "zed_theme_tars_light" = {
      enable = true;
      target = "zed/themes/tars_light.json";
      source = ./tars_light.json;
    };
    "zed_theme_tars_synthwave" = {
      enable = true;
      target = "zed/themes/tars_synthwave.json";
      source = ./tars_synthwave.json;
    };
    "zed_theme_tars_blue" = {
      enable = true;
      target = "zed/themes/tars_blue.json";
      source = ./tars_blue.json;
    };
    "zed_theme_tars_terminal" = {
      enable = true;
      target = "zed/themes/tars_terminal.json";
      source = ./tars_terminal.json;
    };
  };
  programs.zed-editor.userSettings = {
    #########################
    # Theme
    #########################

    theme = lib.mkForce {
      mode = "system";
      light = "TARS Light";
      dark = "TARS Dark";
    };

    icon_theme = {
      mode = "system";
      light = "Catppuccin Latte";
      dark = "Catppuccin Mocha";
    };

  };
}
