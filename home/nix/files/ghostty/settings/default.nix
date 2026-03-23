{ config, ... }:
{
  home.file = {
    "ghostty-settings" = {
      target = "${config.home.homeDirectory}/.config/ghostty/config";
      source = ./config;
    };
  };
}
