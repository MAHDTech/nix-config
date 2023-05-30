{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs; [bash bash-completion nix-bash-completions] ++ unstablePkgs;

  programs.bash = {
    enable = true;
    enableCompletion = true;

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

    # TODO: Transition away from manual rc management.a
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
