# binaries.nix
{...}: {
  home.packages = [
    #(pkgs.callPackage ./tkg.nix {})

    #(pkgs.callPackage ./carvel.nix {})

    #(pkgs.callPackage ./kpack.nix {})

    #(pkgs.callPackage ./pivnet.nix {})

    #(pkgs.callPackage ./ls-colors.nix {})
  ];
}
