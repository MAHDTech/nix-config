{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  home.file = {
    scripts = {
      recursive = true;
      executable = true;

      source = ./../../files/scripts;
      target = "${config.home.homeDirectory}/.local/bin/scripts";
    };
  };
}
