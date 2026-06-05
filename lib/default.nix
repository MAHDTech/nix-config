{ lib, inputs, ... }:
let
  globalUsername = "mahdtech";
  globalStateVersion = "26.05";

  pkgsImportSystem =
    system:
    import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
in
{
  inherit globalUsername globalStateVersion pkgsImportSystem;

  # Helper for standard NixOS hosts
  mkHost =
    {
      name,
      system,
      extraModules ? [ ],
      overlays ? [ ],
    }:
    lib.nixosSystem {
      pkgs = import inputs.nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
        };
      };
      specialArgs = {
        inherit inputs system name;
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
        ../nixos/system/home-manager.nix # Standard HM integration
        ../nixos/hosts/${lib.toLower name}
      ]
      ++ extraModules;
    };

  # Helper for installers
  mkInstaller =
    {
      system,
      module,
      ...
    }:
    lib.nixosSystem {
      pkgs = pkgsImportSystem system;
      specialArgs = { inherit inputs; };
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
        inputs.stylix.homeManagerModules.stylix
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
