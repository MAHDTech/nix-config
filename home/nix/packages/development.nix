{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    hugo
  ];
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

      nodejs-16_x

      pkgconfig

      rust-analyzer
      rustup

      texlive.combined.scheme-full

      zsa-udev-rules
    ]
    ++ unstablePkgs;
}
