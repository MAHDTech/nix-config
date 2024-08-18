{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra
    #cachix # nix profile...
    #devenv # nix profile...
    nil
    nixos-generators
    nixpkgs-fmt
    rnix-lsp
  ];
}
