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
    }:
    lib.nixosSystem {
      pkgs = pkgsImportSystem system;
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
        inputs.sops-nix.nixosModules.sops
        inputs.catppuccin.nixosModules.catppuccin
        inputs.flatpaks.nixosModules.default
        ../nixos/system/home-manager.nix # Standard HM integration
        ../nixos/hosts/${lib.toLower name}
        (_: {
          catppuccin.sources =
            lib.mkForce
              (import "${inputs.catppuccin}/default.nix" {
                pkgs = pkgsImportSystem "x86_64-linux";
              }).packages;
        })
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
        inputs.catppuccin.homeModules.catppuccin
        inputs.sops-nix.homeManagerModules.sops
        (_: {
          catppuccin.sources =
            lib.mkForce
              (import "${inputs.catppuccin}/default.nix" {
                pkgs = pkgsImportSystem "x86_64-linux";
              }).packages;
        })
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
