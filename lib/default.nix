{ lib, inputs, ... }:
let
  globalUsername = "mahdtech";
  globalStateVersion = "26.05";

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
    }:
    let
      common = {
        inherit overlays;
        config = {
          allowUnfree = true;
        };
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

  pkgsImport =
    args:
    importNixpkgs inputs.nixpkgs (args // { overlays = globalOverlays ++ (args.overlays or [ ]); });

  # The unstable channel, handed to every module as `pkgsUnstable` via
  # specialArgs / extraSpecialArgs. Declare it here and nowhere else — modules
  # should take it as an argument rather than re-importing nixpkgs-unstable,
  # which historically drifted on both allowUnfree and cross-compilation.
  #
  # Deliberately without globalOverlays: those packages target the stable set,
  # and duplicating them here would build them twice.
  pkgsUnstableImport = importNixpkgs inputs.nixpkgs-unstable;

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
    }:
    lib.nixosSystem {
      pkgs = pkgsImport {
        inherit system buildSystem overlays;
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
        # They land at normal priority, so they win over the fleet defaults in
        # nixos/system/soe/nix (all lib.mkDefault); anything left unset keeps
        # the fleet default.
        { nix.settings = nixSettings; }
        {
          boot.zfs.forceImportRoot = lib.mkDefault false;
          boot.zfs.forceImportAll = lib.mkDefault false;
        }
        inputs.opnix.nixosModules.default
        inputs.stylix.nixosModules.stylix
        inputs.flatpaks.nixosModules.default
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
      specialArgs = { inherit inputs buildSystem; };
      modules = [
        { system.stateVersion = globalStateVersion; }
        {
          boot.zfs.forceImportRoot = lib.mkDefault false;
          boot.zfs.forceImportAll = lib.mkDefault false;
        }
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
