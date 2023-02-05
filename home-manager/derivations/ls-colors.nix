
##################################################
# Name: ls-colors
# Description: Improves ls with more color
##################################################

let

  pkgs = import <nixpkgs> {} ;

  LS_COLORS = pkgs.fetchurl {

    url = "https://raw.githubusercontent.com/trapd00r/LS_COLORS/master/LS_COLORS";
    sha256 = "sha256-1BTJHaaaxD2XG+FznHSO4bEjUFSFSqqKfkJEhvSHCsM=" ;
  };

in

  pkgs.runCommand "ls-colors" {} ''

    mkdir --parents $out/bin $out/share

    ln -s ${pkgs.coreutils}/bin/ls $out/bin/ls
    ln -s ${pkgs.coreutils}/bin/dircolors $out/bin/dircolors

    cp ${LS_COLORS} $out/share/LS_COLORS

  ''

