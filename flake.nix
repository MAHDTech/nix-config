{
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

    # https://devenv.sh/
    devenv = {
      type = "github";
      owner = "cachix";
      repo = "devenv";
      ref = "main";
      flake = true;
    };

    fenix = {
      type = "github";
      owner = "nix-community";
      repo = "fenix";
      ref = "main";
      flake = true;
    };
  };

  outputs = {
    nixpkgs,
    #nixpkgs-unstable,
    nixos-hardware,
    home-manager,
    sops-nix,
    #nix-colors,
    #statix,
    #devenv,
    #fenix,
    ...
  } @ inputs: let
    globalStateVersion = "22.11";

    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = f:
      builtins.listToAttrs (map (name: {
          inherit name;
          value = f name;
        })
        systems);

    pkgsImportSystem = system: import inputs.nixpkgs {inherit system;};

    #pkgsImportSystemUnstable = system: import inputs.nixpkgs-unstable {inherit system;};

    pkgsAllowUnfree = {
      nixpkgs = {
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
      };
    };

    configHome = {username, ...}: {
      inherit username;
      homeDirectory = "/home/${username}";
      stateVersion = globalStateVersion;
    };

    #########################
    # Home Manager
    #########################

    configHomeManager = {
      system,
      username,
      ...
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsImportSystem system;

        extraSpecialArgs = {
          inherit inputs;
          inherit username;
          inherit globalStateVersion;
          inherit system;
        };

        modules = [
          ./home
          {
            home = configHome {inherit username;};
          }

          pkgsAllowUnfree

          sops-nix.homeManagerModules.sops
        ];
      };

    #########################
    # NixOS
    #########################

    configNixOS = {
      system,
      extraModules,
      username,
      ...
    }:
      nixpkgs.lib.nixosSystem {
        pkgs = pkgsImportSystem system;

        specialArgs = {
          inherit inputs;
          inherit username;
          inherit globalStateVersion;
        };

        modules =
          [
            pkgsAllowUnfree

            sops-nix.nixosModules.sops
          ]
          ++ extraModules;
      };

    configNixOSHomeManager = {username}: {
      useGlobalPkgs = true;
      useUserPackages = true;

      users.${username} = ./home;
      extraSpecialArgs = {
        inherit inputs;
        #inherit username;
        inherit globalStateVersion;
        home = configHome;
      };

      sharedModules = [
        pkgsAllowUnfree

        sops-nix.homeManagerModules.sops
      ];
    };
  in {
    #########################
    # Home Manager Standalone
    #########################

    homeConfigurations = {
      "mahdtech@penguin" = configHomeManager {
        system = "x86_64-linux";
        username = "mahdtech";
      };

      "matthewd3@vmware.lab" = configHomeManager {
        system = "x86_64-linux";
        username = "matthewd3@vmware.lab";
      };
    };

    #########################
    # NixOS Hosts
    #########################

    nixosConfigurations = {
      nuc = configNixOS {
        username = "mahdtech";
        system = "x86_64-linux";

        extraModules = [
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel

          ./hosts/nuc
          {system.stateVersion = globalStateVersion;}

          home-manager.nixosModules.home-manager
          {
            home-manager = configNixOSHomeManager {username = "mahdtech";};
          }
        ];
      };

      vmware = configNixOS {
        username = "mahdtech";
        system = "x86_64-linux";

        extraModules = [
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel

          ./hosts/nuc
          {system.stateVersion = globalStateVersion;}
        ];
      };
    };

    #########################
    # Dev Shells
    # nix develop --impure .#${NAME}
    #########################

    devShells = forAllSystems (system: let
      pkgs = pkgsImportSystem system;
    in {
      default = import ./devshells/default {
        inherit inputs;
        inherit pkgs;
      };

      nix = import ./devshells/nix {
        inherit inputs;
        inherit pkgs;
      };

      salt = import ./devshells/salt {
        inherit inputs;
        inherit pkgs;
      };
    });
  };
}
