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
    };

    nix-colors = {
      type = "github";
      owner = "misterio77";
      repo = "nix-colors";
      ref = "main";
      flake = true;
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
      nixpkgs.config = {
        allowUnfree = true;
        allowUnfreePredicate = (pkg: true);
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

      pkgs = pkgsImportSystem system;

      extraSpecialArgs = {
        inherit inputs;
        inherit outputs;
      };

      modules = [

        pkgsAllowUnfree

        ./home {
          home = configHome;
        }

      ];

    };

    #########################
    # NixOS
    #########################

    configNixOS = { system, extraModules, ... }: nixpkgs.lib.nixosSystem rec {

      system = system;

      specialArgs = {
        inherit system;
        inherit inputs;
        inherit outputs;
      };

      modules = [

        pkgsAllowUnfree

        #home-manager.nixosModules.home-manager {
        #  home-manager = {
        #    useGlobalPkgs = true;
        #    useUserPackages = true;
        #    users.${username} = import ./home;
        #  };
        #}

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

        extraSpecialArgs = { inherit inputs outputs; };

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

        ];

      };

      zim = configNixOS {

        system = "x86_64-linux";

        extraModules = [

          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-gpu-amd

          ./hosts/zim {
            system.stateVersion = globalStateVersion;
          }

        ];

      };

    };

    #########################
    # Dev Shells
    #########################

    /*
    # TODO: Finish this.
    devShells = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./shells { inherit pkgs; }
    );
    */

  };

}
