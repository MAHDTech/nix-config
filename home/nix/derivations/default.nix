{
  #home.packages = [
  # Cursor
  # On ChromeOS use AppImage directly.
  # On NixOS, now available in nixpkgs
  #(pkgs.callPackage ./cursor.nix {})

  #(pkgs.callPackage ./tkg.nix {})

  #(pkgs.callPackage ./carvel.nix {})

  #(pkgs.callPackage ./kpack.nix {})

  #(pkgs.callPackage ./pivnet.nix {})

  #(pkgs.callPackage ./ls-colors.nix { })
  #]
  #++
  # Bambu Studio only available on AMD64.
  #(lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
  #  pkgs.callPackage ./BambuStudio.nix { }
  #));
  #}
}
