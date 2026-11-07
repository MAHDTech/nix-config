{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  claude-code = pkgs.callPackage ./claude-code { };
  codex = pkgs.callPackage ./codex { };

  # Tracks upstream releases faster than nixpkgs;
  # bump with t3code/update.sh.
  # The wrapper puts the enabled agent CLIs on t3code's PATH, so they must be
  # the same builds installed elsewhere in this config.
  t3code = pkgs.callPackage ./t3code {
    # Inherit the custom pkgs
    inherit claude-code codex;
    # Inherit nixpkgs unstable
    inherit (pkgsUnstable) opencode grok-build;

    # What to enable for access from inside t3code
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

  wakatimeDesktop =
    if pkgs.stdenv.hostPlatform.isLinux then [ (pkgs.callPackage ./wakatime-desktop { }) ] else [ ];

  unstablePkgs = with pkgsUnstable; [
    codex
  ];
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
    #claude-code
    codex
    t3code
    #(pkgs.callPackage ./ls-colors.nix { })
  ]
  ++ bambuStudio
  ++ wakatimeDesktop
  ++ unstablePkgs;
  systemd.user.services.t3code = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "T3 Code server";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${t3code}/bin/t3 serve --base-dir %h/.t3";
      WorkingDirectory = "%h";
      Environment = [
        "T3CODE_HOME=%h/.t3"
        "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
      ];
      EnvironmentFile = "-%h/.t3/service.env";
      Restart = "on-failure";
      RestartSec = 5;
      KillMode = "mixed";
      TimeoutStopSec = 30;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
