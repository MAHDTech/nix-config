{ config, ... }:
{
  home.file = {
    "opencode-theme-tars-dark" = {
      target = "${config.home.homeDirectory}/.config/opencode/themes/tars_dark.json";
      source = ./tars_dark.json;
    };
    "opencode-theme-tars-light" = {
      target = "${config.home.homeDirectory}/.config/opencode/themes/tars_light.json";
      source = ./tars_light.json;
    };
    "opencode-theme-tars-synthwave" = {
      target = "${config.home.homeDirectory}/.config/opencode/themes/tars_synthwave.json";
      source = ./tars_synthwave.json;
    };
    "opencode-theme-tars-blue" = {
      target = "${config.home.homeDirectory}/.config/opencode/themes/tars_blue.json";
      source = ./tars_blue.json;
    };
  };
}
