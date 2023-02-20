{pkgs, ...}: let
  src = pkgs.fetchurl {
    name = "LS_COLORS";
    url = "https://raw.githubusercontent.com/trapd00r/LS_COLORS/master/LS_COLORS";
    sha256 = "sha256-U9ivaC2JbZ5wOwZyQbbSa3AZxDsGguifqjho6lTmC+Y=";
  };
in
  pkgs.stdenv.mkDerivation rec {
    name = "ls-colors";
    version = "1.0.0";

    buildInputs = [pkgs.coreutils];

    phases = ["installPhase"];

    installPhase = ''

      echo "Building ls-colors..."

      mkdir --parents $out/bin

      ${pkgs.coreutils}/bin/dircolors \
        --bourne-shell \
          ${src} > \
          $out/bin/ls-colors-bash.sh

      ${pkgs.coreutils}/bin/dircolors \
        --c-shell \
          ${src} > \
          $out/bin/ls-colors-csh.sh

      chmod +x $out/bin/ls-colors-*.sh
    '';
  }
