{

  description = "NixOS and home-manager configurations";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    nur.url = "github:nix-community/nur";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { home-manager, nur, nixos-hardware, nixpkgs, ... }:

    let

      homeManagerConfFor = config:
        { ... }: {
          nixpkgs.overlays = [
            nur.overlay
          ];
          imports = [ config ];
        };

    in {

      # 'NUC' is an Intel NUC X15 Laptop
      nixosConfigurations.nuc = nixpkgs.lib.nixosSystem {

        system = "x86_64-linux";

        specialArgs = { inherit nixpkgs; };

        modules = [

          #nixos-hardware.nixosModules.XXX
          ./hosts/nuc/configuration.nix

          home-manager.nixosModules.home-manager {
            home-manager.useUserPackages = true;
            home-manager.users.mahdtech =
              homeManagerConfFor ./home-manager/home.nix;
          }

        ];

      };

    };

}