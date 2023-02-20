{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
      cmake
      gcc
      gdb
      glib
      glibc
      gnumake
      gnupatch

      go
      gofumpt
      golangci-lint
      golint

      graphviz

      haskellPackages.hadolint
      haskellPackages.language-docker

      hidapi

      hugo

      nodejs-16_x

      pkgconfig

      rust-analyzer
      rustup

      texlive.combined.scheme-full

      zsa-udev-rules
    ]
    ++ unstablePkgs;
}
