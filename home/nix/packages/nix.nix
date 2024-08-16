{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra
    cachix
    devenv
    nil
    nixos-generators
    nixpkgs-fmt
    rnix-lsp
  ];
}
