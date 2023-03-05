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
