{

  description = "NixOS and home-manager configurations";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = {

    nixpkgs,
    nixpkgs-unstable,
    nixos-hardware,
    home-manager,
    ...

  }:

    let

      homeManagerConfFor = config:
        { ... }: {
          nixpkgs.overlays = [
          ];
          imports = [ config ];
        };

    in {

      #########################
      # Hostname: NUC
      # System: Intel NUC X15 Laptop
      #########################

      nixosConfigurations.nuc = nixpkgs.lib.nixosSystem {

        system = "x86_64-linux";
        specialArgs = { inherit nixpkgs; };

        modules = [

          #nixos-hardware.nixosModules.X-X-X

          ./nixos/systems/nuc/configuration.nix

          home-manager.nixosModules.home-manager {

            home-manager = {

              useUserPackages = true;
              useGlobalPkgs = false;

              users.mahdtech = homeManagerConfFor ./home-manager/home.nix;

            };

          }

        ];

      };

      #########################
      # Hostname: ZIM
      # System: AMD Ryzen Desktop with integrated graphics.
      #########################

      nixosConfigurations.zim = nixpkgs.lib.nixosSystem {

        system = "x86_64-linux";
        specialArgs = { inherit nixpkgs; };

        modules = [

          #nixos-hardware.nixosModules.X.X.X

          ./nixos/systems/zim/configuration.nix

          home-manager.nixosModules.home-manager {

            home-manager = {

              useUserPackages = true;
              useGlobalPkgs = false;

              users.mahdtech = homeManagerConfFor ./home-manager/home.nix;

            };

          }

        ];

      };

      #########################
      # End
      #########################

    };

}
