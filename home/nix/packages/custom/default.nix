{
  pkgs,
  ...
}:
let
  litert-lm = pkgs.callPackage ./litert-lm.nix { };
in
{
  home.packages = [
    #(pkgs.callPackage ./BambuStudio.nix { })
    #(pkgs.callPackage ./OrcaSlicer.nix { })

    #(pkgs.callPackage ./cursor.nix {})

    #(pkgs.callPackage ./tkg.nix {})

    #(pkgs.callPackage ./carvel.nix {})

    #(pkgs.callPackage ./kpack.nix {})

    #(pkgs.callPackage ./pivnet.nix {})

    litert-lm
    (pkgs.callPackage ./gemini-cli.nix { inherit litert-lm; })

    #(pkgs.callPackage ./ls-colors.nix { })

  ];
}
