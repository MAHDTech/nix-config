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

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixos-hardware,
    home-manager,
    sops-nix,
    ...
  }: let

    #########################
    # Common
    #########################

    username = "mahdtech";

    # It's perfectly fine and recommended to leave this value at the release version of the first install of this system.
    # Changing this option will not upgrade your system.
    # In fact it is meant to stay constant exactly when you upgrade your system.
    # You should only bump this option, if you are sure that you can or have migrated all state on your system which is affected by this option.
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

    configHomeManager = { system, extraSpecialArgs, ... }: home-manager.lib.homeManagerConfiguration rec {

      inherit system;

      pkgs = pkgsImportSystem system;

      extraSpecialArgs = {
        inherit nixpkgs;
        inherit nixpkgs-unstable;
        inherit username;
      };

      modules = [

        ./home {
          home = configHome;
        }

        pkgsAllowUnfree

        #sops-nix.nixosModules.sops

      ];

    };

    #########################
    # NixOS
    #########################

    configNixOS = { system, extraModules, ... }: nixpkgs.lib.nixosSystem rec {

      inherit system;

      pkgs = pkgsImportSystem system;

      specialArgs = {
        inherit nixpkgs;
        inherit nixpkgs-unstable;
        inherit username;
      };

      modules = [

        home-manager.nixosModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;

            users.${username} = import ./home;
            extraSpecialArgs = {
	            inherit globalStateVersion;
	            home = configHome;
            };

          };
        }

        pkgsAllowUnfree

        #sops-nix.nixosModules.sops

      ] ++ extraModules;

    };

  in {

    #########################
    # Home Manager Standalone
    #########################

    homeConfigurations = {

      "${username}@penguin" = configHomeManager {

        system = "x86_64-linux";

        extraSpecialArgs = {

        };

      };

    };

    #########################
    # NixOS Hosts
    #########################

    nixosConfigurations = {

      nuc = configNixOS {

        system = "x86_64-linux";

        extraModules = [

          pkgsAllowUnfree

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
