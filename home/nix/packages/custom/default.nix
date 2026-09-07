{
  pkgs,
  pkgsUnstable,
  ...
}:
let
  claude-code = pkgs.callPackage ./claude-code { };
  # Remove once nixpkgs codex >= 0.153.4 and re-enable codex in ../tools.nix
  codex = pkgs.callPackage ./codex { };

  # Tracks upstream releases faster than nixpkgs; bump with t3code/update.sh.
  # The wrapper puts the enabled agent CLIs on t3code's PATH, so they must be
  # the same builds installed elsewhere in this config.
  t3code = pkgs.callPackage ./t3code {
    inherit claude-code codex;
    inherit (pkgsUnstable) opencode grok-build;
    enableClaude = true;
    enableCodex = true;
    enableOpencode = true;
    enableGrokBuild = true;
  };

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
    claude-code
    codex
    t3code
    #(pkgs.callPackage ./ls-colors.nix { })
  ]
  ++ bambuStudio;
}
