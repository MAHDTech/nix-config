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

      nodejs-16_x

      Rust
      rustup
      clang
      llvm

      shfmt

      texlive.combined.scheme-full
    ]
    ++ unstablePkgs;
}
