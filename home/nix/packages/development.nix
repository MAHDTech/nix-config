{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
  ];
in {
  home.packages = with pkgs; [
    bob
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

    Rust
    rustup
    clang
    llvm

    shfmt

    texlive.combined.scheme-full
  ];
  #++ unstablePkgs;
}
