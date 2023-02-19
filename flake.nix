{

  # Thanks to Misterio77 for the awesome starter configs
  # https://github.com/Misterio77/nix-starter-configs

  description = "NixOS and Home Manager configuration";

  inputs = {

    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-22.11";
      flake = true;
    };

    nixpkgs-unstable = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
      flake = true;
    };

    nixos-hardware = {
      type = "github";
      owner = "NixOS";
      repo = "nixos-hardware";
      ref = "master";
      flake = true;
    };

    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      #ref = "master";
      ref = "release-22.11";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      type = "github";
      owner = "Mic92";
      repo = "sops-nix";
      ref = "master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors = {
      type = "github";
      owner = "misterio77";
      repo = "nix-colors";
      ref = "main";
      flake = true;
    };

    statix = {
      type = "github";
      owner = "nerdypepper";
      repo = "statix";
      ref = "master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixos-hardware,
    home-manager,
    sops-nix,
    ...
  }@inputs:

  let

    username = "mahdtech";

    globalStateVersion = "22.11";

    inherit (self) outputs;

    pkgsImportSystem = system: import inputs.nixpkgs {
      inherit system;
    };

    pkgsAllowUnfree = {
      nixpkgs = {
        config = {
          allowUnfree = true;
          allowUnfreePredicate = (_: true);
        };
      };
    };

    configHome = {
      inherit username;
      homeDirectory = "/home/${username}";
      stateVersion = globalStateVersion;
    };

    forAllSystems = nixpkgs.lib.genAttrs [
      "aarch64-darwin"
      "aarch64-linux"
      "i686-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    #########################
    # Home Manager
    #########################

    configHomeManager = { system, ... }: home-manager.lib.homeManagerConfiguration rec {

      pkgs = pkgsImportSystem system;

      extraSpecialArgs = {
        inherit inputs;
        inherit username;
        inherit globalStateVersion;
      };

      modules = [

        ./home {
          home = configHome;
        }

        pkgsAllowUnfree

        sops-nix.nixosModules.sops

      ];

    };

    #########################
    # NixOS
    #########################

    configNixOS = { system, extraModules, ... }: nixpkgs.lib.nixosSystem rec {

      pkgs = pkgsImportSystem system;

      specialArgs = {
        inherit inputs;
        inherit username;
        inherit globalStateVersion;
      };

      modules = [

        pkgsAllowUnfree

        sops-nix.nixosModules.sops

      ] ++ extraModules;

    };

    configNixOSHomeManager = {
        useGlobalPkgs = true;
        useUserPackages = true;

        users.${username} = ./home;
        extraSpecialArgs = {
          inherit globalStateVersion;
          home = configHome;
        };
    };

  in {

    #########################
    # Home Manager Standalone
    #########################

    homeConfigurations = {

      "${username}@penguin" = configHomeManager {

        system = "x86_64-linux";

      };

    };

    #########################
    # NixOS Hosts
    #########################

    nixosConfigurations = {

      nuc = configNixOS {

        system = "x86_64-linux";

        extraModules = [

          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel

          ./hosts/nuc {
            system.stateVersion = globalStateVersion;
          }

          home-manager.nixosModules.home-manager {
            home-manager = configNixOSHomeManager;
          }

        ];

      };

      vmware = configNixOS {

        system = "x86_64-linux";

        extraModules = [

          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel

          ./hosts/nuc {
            system.stateVersion = globalStateVersion;
          }

        ];

      };

    };

    #########################
    # Dev Shells
    #########################

    /*
    devShells = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./shells { inherit pkgs; }
    );
    */

  };

}
