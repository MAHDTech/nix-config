{pkgs, ...}: let
  src = pkgs.fetchurl {
    name = "LS_COLORS";
    url = "https://raw.githubusercontent.com/trapd00r/LS_COLORS/master/LS_COLORS";
    sha256 = "sha256-B79qpolB+QY2WtcEqAH+HwImm0Ykb4Bo4USFXmiSPTs=";
  };
in
  pkgs.stdenv.mkDerivation {
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
