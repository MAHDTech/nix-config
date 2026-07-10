{
  pkgs,
  ...
}:
let
  litert-lm = pkgs.callPackage ./litert-lm.nix { };

  bambuStudio =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      [ (pkgs.callPackage ./BambuStudio.nix { }) ]
    else
      [ ];
in
{
  home.packages = [
    #(pkgs.callPackage ./OrcaSlicer.nix { })

    #(pkgs.callPackage ./cursor.nix {})

    #(pkgs.callPackage ./tkg.nix {})

    #(pkgs.callPackage ./carvel.nix {})

    #(pkgs.callPackage ./kpack.nix {})

    #(pkgs.callPackage ./pivnet.nix {})

    litert-lm
    (pkgs.callPackage ./antigravity-cli { })
    (pkgs.callPackage ./antigravity-hub { })

    #(pkgs.callPackage ./ls-colors.nix { })

  ]
  ++ bambuStudio;
}
