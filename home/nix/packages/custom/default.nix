{
  #pkgs,
  _,
}:
{
  home.packages = [
    #(pkgs.callPackage ./BambuStudio.nix { })
    #(pkgs.callPackage ./OrcaSlicer.nix { })

    #(pkgs.callPackage ./cursor.nix {})

    #(pkgs.callPackage ./tkg.nix {})

    #(pkgs.callPackage ./carvel.nix {})

    #(pkgs.callPackage ./kpack.nix {})

    #(pkgs.callPackage ./pivnet.nix {})

    #(pkgs.callPackage ./gemini-cli.nix { })

    #(pkgs.callPackage ./ls-colors.nix { })
  ];
}
