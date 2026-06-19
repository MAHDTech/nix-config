{ lib, inputs, ... }:
let
  globalUsername = "mahdtech";
  globalStateVersion = "26.05";

  # Import nixpkgs for a given system, with optional cross-compilation.
  # When buildSystem != system, configures localSystem/crossSystem for
  # native cross-compilation (no QEMU emulation).
  pkgsImport =
    {
      system,
      buildSystem ? system,
      overlays ? [ ],
    }:
    if buildSystem == system then
      # Native build — standard import
      import inputs.nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
        };
      }
    else
      # Cross-compilation — build natively on buildSystem, target system
      import inputs.nixpkgs {
        localSystem = buildSystem;
        crossSystem = system;
        inherit overlays;
        config = {
          allowUnfree = true;
        };
      };

  # Backwards-compatible simple import (used by mkHome)
  pkgsImportSystem = system: pkgsImport { inherit system; };
in
{
  inherit globalUsername globalStateVersion pkgsImportSystem;

  # Helper for standard NixOS hosts
  mkHost =
    {
      name,
      system,
      buildSystem ? system, # defaults to native; set to differ for cross-compilation
      hostType ? "desktop",
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
          ;
        username = globalUsername;
        inherit globalUsername globalStateVersion;
      };
      modules = [
        { system.stateVersion = globalStateVersion; }
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
      buildSystem ? system, # defaults to native; set to differ for cross-compilation
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
      };
    };
}
