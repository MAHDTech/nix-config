{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
      #alejandra
      #nil
      #nixos-generators
      #nixpkgs-fmt
      #rnix-lsp cachix
    ]
    ++ unstablePkgs;
}
