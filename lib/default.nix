{ lib, inputs, ... }:
let
  globalUsername = "mahdtech";
  globalStateVersion = import ./stateVersion.nix;

  # Repository-wide overlays, applied ahead of any caller-supplied ones.
  # See ../overlays/default.nix.
  globalOverlays = [ (import ../overlays) ];

  # Import a nixpkgs source for a given system, with optional cross-compilation.
  # When buildSystem != system, configures localSystem/crossSystem for
  # native cross-compilation (no QEMU emulation).
  importNixpkgs =
    source:
    {
      system,
      buildSystem ? system,
      overlays ? [ ],
      nixpkgsConfig ? { },
    }:
    let
      common = {
        inherit overlays;
        config = {
          allowUnfree = true;
        }
        // nixpkgsConfig;
      };
    in
    if buildSystem == system then
      # Native build — standard import
      import source (common // { inherit system; })
    else
      # Cross-compilation — build natively on buildSystem, target system
      import source (
        common
        // {
          localSystem = buildSystem;
          crossSystem = system;
        }
      );

  # Memoize default (buildSystem, system) package sets so all hosts and
  # installers share one evaluated nixpkgs instance per platform pair.
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  unstableOverlays = [
    (final: prev: {
      # Remove when the pinned OpenCode dependency hash is fixed upstream.
      opencode = prev.opencode.overrideAttrs (
        old:
        final.lib.optionalAttrs
          (old.version == "2.2.5" && prev.stdenv.hostPlatform.system == "x86_64-linux")
          {
            node_modules = old.node_modules.overrideAttrs {
              outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
            };
          }
      );
    })
  ];

  mkMemoizedPkgs =
    source: overlays:
    lib.genAttrs supportedSystems (
      buildSystem:
      lib.genAttrs supportedSystems (
        system:
        importNixpkgs source {
          inherit system buildSystem overlays;
        }
      )
    );

  defaultPkgs = mkMemoizedPkgs inputs.nixpkgs globalOverlays;
  unstableMatchesStable = inputs.nixpkgs.outPath == inputs.nixpkgs-unstable.outPath;
  defaultUnstablePkgs =
    if unstableMatchesStable then
      defaultPkgs
    else
      mkMemoizedPkgs inputs.nixpkgs-unstable unstableOverlays;

  pkgsImport =
    {
      system,
      buildSystem ? system,
      overlays ? [ ],
      nixpkgsConfig ? { },
    }:
    if
      overlays == [ ]
      && nixpkgsConfig == { }
      && builtins.elem buildSystem supportedSystems
      && builtins.elem system supportedSystems
    then
      defaultPkgs.${buildSystem}.${system}
    else
      importNixpkgs inputs.nixpkgs {
        inherit system buildSystem nixpkgsConfig;
        overlays = globalOverlays ++ overlays;
      };

  # The unstable channel, handed to every module as `pkgsUnstable` via
  # specialArgs / extraSpecialArgs. When nixpkgs and nixpkgs-unstable resolve
  # to the same revision, this reuses `defaultPkgs` so evaluation loads one
  # nixpkgs tree instead of two; when nixpkgs tracks a stable release, it
  # evaluates nixpkgs-unstable without globalOverlays.
  pkgsUnstableImport =
    {
      system,
      buildSystem ? system,
      overlays ? [ ],
      nixpkgsConfig ? { },
    }:
    if
      overlays == [ ]
      && nixpkgsConfig == { }
      && builtins.elem buildSystem supportedSystems
      && builtins.elem system supportedSystems
    then
      defaultUnstablePkgs.${buildSystem}.${system}
    else if unstableMatchesStable then
      pkgsImport {
        inherit
          system
          buildSystem
          overlays
          nixpkgsConfig
          ;
      }
    else
      importNixpkgs inputs.nixpkgs-unstable {
        inherit system buildSystem nixpkgsConfig;
        overlays = unstableOverlays ++ overlays;
      };

  # Backwards-compatible simple import (used by mkHome)
  pkgsImportSystem = system: pkgsImport { inherit system; };

  # Render a `nixSettings` attrset as `nix` CLI flags, so unattended rebuilds
  # (system.autoUpgrade) honour the same limits as nix.settings. `--option
  # <name> <value>` accepts any Nix setting, so adding a new key to a host's
  # nixSettings needs no change here.
  mkNixSettingsFlags =
    settings:
    lib.concatMap (
      name:
      let
        value = settings.${name};
        rendered =
          if lib.isBool value then
            lib.boolToString value
          else if lib.isList value then
            lib.concatMapStringsSep " " toString value
          else
            toString value;
      in
      [
        "--option"
        name
        rendered
      ]
    ) (lib.attrNames settings);
in
{
  inherit
    globalUsername
    globalStateVersion
    pkgsImportSystem
    # Exported for consumers that cannot receive specialArgs — currently only
    # the devenv devShell (devenv/dotfiles.nix). NixOS and home-manager modules
    # should take `pkgsUnstable` as an argument instead.
    pkgsUnstableImport
    ;

  # Helper for standard NixOS hosts
  mkHost =
    {
      name,
      system,
      buildSystem ? builtins.currentSystem or system,
      hostType ? "desktop",
      nixSettings ? { },
      extraModules ? [ ],
      overlays ? [ ],
      enableHomeManager ? true,
      nixpkgsConfig ? { },
    }:
    lib.nixosSystem {
      pkgs = pkgsImport {
        inherit
          system
          buildSystem
          overlays
          nixpkgsConfig
          ;
      };
      specialArgs = {
        inherit
          inputs
          system
          buildSystem
          name
          hostType
          nixSettings
          ;
        # The same settings rendered as `nix` CLI flags, for modules that shell
        # out (system.autoUpgrade.flags). See mkNixSettingsFlags.
        nixSettingsFlags = mkNixSettingsFlags nixSettings;
        username = globalUsername;
        inherit globalUsername globalStateVersion;

        # Available to every NixOS module as `pkgsUnstable`. Lazy, so hosts
        # that never reference it pay no evaluation cost.
        pkgsUnstable = pkgsUnstableImport { inherit system buildSystem; };
      };
      modules = [
        { system.stateVersion = globalStateVersion; }
        # Host-specific Nix tuning, declared per host as `nixSettings` in
        # nixos/hosts/default.nix. Keys are real nix.settings names, passed
        # through verbatim — any Nix setting works without touching this file.
        # They land at normal priority, so they win over the lib.mkDefault
        # fleet defaults in nixos/system/soe/nix; anything left unset keeps the
        # fleet default. Exceptions: trusted-users and system-features are set
        # at normal priority there (see the comment in that file), so a host
        # override merges with them rather than replacing them.
        { nix.settings = nixSettings; }
        (
          { config, pkgs, ... }:
          {
            boot = {
              kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
              zfs = {
                forceImportRoot = lib.mkDefault false;
                forceImportAll = lib.mkDefault false;
              };
            };
            # Swap on ZFS zvols/datasets risks kernel deadlocks under OOM (openzfs#7734).
            zramSwap = lib.mkIf config.boot.zfs.enabled {
              enable = lib.mkDefault true;
              algorithm = lib.mkDefault "zstd";
              memoryPercent = lib.mkDefault 50;
              memoryMax = lib.mkDefault (32 * 1024 * 1024 * 1024);
            };
          }
        )
        inputs.opnix.nixosModules.default
        inputs.stylix.nixosModules.stylix
        inputs.flatpaks.nixosModules.default
        ../nixos/system/config/services/nixos-upgrade
        ../nixos/hosts/${lib.toLower name}
      ]
      ++ lib.optional enableHomeManager ../nixos/system/home-manager.nix
      ++ extraModules;
    };

  # Helper for installers
  mkInstaller =
    {
      system,
      buildSystem ? builtins.currentSystem or system,
      module,
      ...
    }:
    lib.nixosSystem {
      pkgs = pkgsImport { inherit system buildSystem; };
      specialArgs = {
        inherit inputs buildSystem;
        inherit (inputs) self;
      };
      modules = [
        { system.stateVersion = globalStateVersion; }
        ({ pkgs, ... }: {
          boot = {
            kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
            zfs = {
              forceImportRoot = lib.mkDefault false;
              forceImportAll = lib.mkDefault false;
            };
          };
        })
        module
      ];
    };

  # Helper for standalone Home Manager
  mkHome =
    {
      system,
      username ? globalUsername,
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsImportSystem system;
      modules = [
        ../home
        inputs.stylix.homeModules.stylix
        inputs.opnix.homeManagerModules.default
        inputs.cosmic-manager.homeManagerModules.default
      ];
      extraSpecialArgs = {
        inherit
          inputs
          globalUsername
          globalStateVersion
          system
          username
          ;
        inCI = false;
        isNixosHM = false;
        syncthingConfig = null;
        pkgsUnstable = pkgsUnstableImport { inherit system; };
      };
    };
}
