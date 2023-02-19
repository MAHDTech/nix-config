{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: bash.nix
# Description: Bash config using home-manager
##################################################

{

  programs.bash = {

    enable = true;

    historyControl = [

      "ignoredups"
      "ignorespace"

    ];

    initExtra = ''

    '';

    shellAliases = {

    };

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

      source = ./../files/rc.sh;
      target = ".shrc" ;

    };

  };

  xdg.configFile = {

    "rc" = {

      source = ./../files/bash;
      target = "bash" ;

      recursive = true;

    };

  };

}
