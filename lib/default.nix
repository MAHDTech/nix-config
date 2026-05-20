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
        inputs.sops-nix.nixosModules.sops
        inputs.catppuccin.nixosModules.catppuccin
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
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        { system.stateVersion = globalStateVersion; }
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
        inputs.catppuccin.homeManagerModules.catppuccin
        inputs.sops-nix.homeManagerModules.sops
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
      };
    };
}
