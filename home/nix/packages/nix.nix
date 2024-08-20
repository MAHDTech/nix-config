{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra
    nil
    nixos-generators
    nixpkgs-fmt
    rnix-lsp
  ];
}
