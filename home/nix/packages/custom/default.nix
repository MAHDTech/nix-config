{
  pkgs,
  ...
}:
let

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
    #(pkgs.callPackage ./litert-lm.nix {})
    (pkgs.callPackage ./antigravity-cli { })
    (pkgs.callPackage ./antigravity-hub { })
    (pkgs.callPackage ./claude-code { })
    # Remove once nixpkgs codex >= 0.153.4 and re-enable codex in ../tools.nix
    (pkgs.callPackage ./codex { })
    #(pkgs.callPackage ./ls-colors.nix { })
  ]
  ++ bambuStudio;
}
