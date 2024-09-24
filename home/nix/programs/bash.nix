{pkgs, ...}: {
  home.packages = with pkgs; [bashInteractive bash-completion nix-bash-completions];

  programs.bash = {
    enable = true;
    enableCompletion = true;

    package = pkgs.bashInteractive;

    historyControl = ["ignoredups" "ignorespace"];
    historyIgnore = ["sops"];
    historySize = 10000;

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
    # These are added to the top of .bashrc
    bashrcExtra = ''
    '';

    initExtra = ''
      . ~/.shrc
    '';

    logoutExtra = ''
    '';

    profileExtra = ''
    '';

    sessionVariables = {
      EDITOR = "vim";
    };
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
