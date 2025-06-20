{ pkgs, ... }:
{
  home.packages = [
    # Bambu Studio
    #(pkgs.callPackage ./BambuStudio.nix { })

    # Cursor
    # On ChromeOS use AppImage directly.
    # On NixOS, now available in nixpkgs
    #(pkgs.callPackage ./cursor.nix {})

    #(pkgs.callPackage ./tkg.nix {})

    #(pkgs.callPackage ./carvel.nix {})

    #(pkgs.callPackage ./kpack.nix {})

    #(pkgs.callPackage ./pivnet.nix {})

    (pkgs.callPackage ./ls-colors.nix { })
  ];
}
