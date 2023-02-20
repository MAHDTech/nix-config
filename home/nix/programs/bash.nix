{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  programs.bash = {
    enable = true;

    historyControl = ["ignoredups" "ignorespace"];

    initExtra = "\n";

    shellAliases = {};

    shellOptions = [
      "cmdhist"
      "histappend"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
    ];

    # TODO: Transition away from manual rc management.
    bashrcExtra = ''
      . ~/.shrc
    '';
  };

  home.file = {
    ".shrc" = {
      source = ./../../files/rc.sh;
      target = ".shrc";
    };
  };

  xdg.configFile = {
    "rc" = {
      source = ./../../files/bash;
      target = "bash";

      recursive = true;
    };
  };
}
