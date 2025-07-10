{
  description = "NixOS and Home Manager configuration";

  nixConfig = {
    extra-substituters = "https://devenv.cachix.org https://salt-labs.cachix.org https://cosmic.cachix.org/";
    extra-trusted-public-keys = "
      devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
      salt-labs.cachix.org-1:9lBlhm9rPAHrb1GXnclFomAHsnj3kV+4DyJspy/nQlw=
      cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=
    ";
    extra-experimental-features = "nix-command flakes";
    warn-dirty = true;
  };

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "release-25.05";
      #ref = "nixos-unstable";
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

    systems = {
      type = "github";
      owner = "nix-systems";
      repo = "default";
      ref = "main";
      flake = true;
    };

    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      #ref = "release-25.05";
      ref = "master";
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

    cachix = {
      type = "github";
      owner = "cachix";
      repo = "cachix";
      ref = "master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv = {
      type = "github";
      owner = "cachix";
      repo = "devenv";
      ref = "main";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-cosmic = {
      type = "github";
      owner = "lilyinstarlight";
      repo = "nixos-cosmic";
      ref = "main";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flatpaks = {
      type = "github";
      owner = "in-a-dil-emma";
      repo = "declarative-flatpak";
      ref = "stable-v3";
      flake = true;
    };

    catppuccin = {
      type = "github";
      owner = "catppuccin";
      repo = "nix";
      ref = "release-1.x";
      flake = true;
    };

    ags = {
      type = "github";
      owner = "Aylur";
      repo = "ags";
      ref = "v2.3.0";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    matugen = {
      type = "github";
      owner = "InioX";
      repo = "matugen";
      ref = "v2.4.1";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    musnix = {
      type = "github";
      owner = "musnix";
      repo = "musnix";
      ref = "master";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      catppuccin,
      devenv,
      flatpaks,
      home-manager,
      musnix,
      nixos-cosmic,
      nixos-hardware,
      nixpkgs,
      self,
      sops-nix,
      systems,
      ...
    }@inputs:
    let
      # Whoami
      globalUsername = "mahdtech";

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It's perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      globalStateVersion = "24.05";

      #########################
      # Systems functions
      #########################

      forEachSystem = nixpkgs.lib.genAttrs (import systems);

      #########################
      # Packages functions
      #########################

      pkgsImportSystem =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      #########################
      # NixOS functions
      #########################

      configNixOS =
        {
          username,
          system,
          extraModules,
          ...
        }:
        nixpkgs.lib.nixosSystem {
          pkgs = pkgsImportSystem system;

          specialArgs = {
            inherit inputs;
            inherit username;
            inherit globalStateVersion;
          };

          modules = [
            sops-nix.nixosModules.sops
          ] ++ extraModules;
        };

      #########################
      # Home Manager functions
      #########################

      # Home Manager (standalone)
      mkHomeConfigurations =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsImportSystem system;
          modules = [
            ./home

            catppuccin.homeManagerModules.catppuccin
            #home-manager.nixosModules.home-manager
            sops-nix.homeManagerModules.sops
          ];
          extraSpecialArgs = {
            inherit inputs;
            inherit globalStateVersion;
            inherit globalUsername;
            inherit system;
          };
        };
    in
    {
      #########################
      # NixOS
      #########################

      nixosConfigurations = {
        # Hostname: TEMPLATE
        # Description: VMware VM used as a template for new hosts.
        TEMPLATE = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/template

            catppuccin.nixosModules.catppuccin
          ];
        };

        # Hostname: NIXOS-1
        # Description: VMware VM running NixOS used as a Jump Box.
        NIXOS-1 = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/nixos-1

            catppuccin.nixosModules.catppuccin
          ];
        };

        # Hostname: NUC
        # Description: Intel X15 NUC Laptop with Intel ARC GPU
        NUC = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/nuc

            catppuccin.nixosModules.catppuccin
            flatpaks.nixosModule
            home-manager.nixosModules.home-manager
            musnix.nixosModules.default
            nixos-cosmic.nixosModules.default
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-gpu-intel
            nixos-hardware.nixosModules.common-hidpi
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-pc-ssd
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  inherit globalStateVersion;
                  inherit globalUsername;
                };
                users.${globalUsername} = {
                  imports = [
                    ./home

                    sops-nix.homeManagerModules.sops
                    catppuccin.homeManagerModules.catppuccin
                  ];
                };
              };
            }
          ];
        };

        # Hostname: JONS
        # Description: Jonsplus Desktop with AMD CPU and Intel ARC GPU
        JONS = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/jons

            catppuccin.nixosModules.catppuccin
            flatpaks.nixosModule
            home-manager.nixosModules.home-manager
            musnix.nixosModules.default
            nixos-cosmic.nixosModules.default
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-intel
            nixos-hardware.nixosModules.common-hidpi
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  inherit globalStateVersion;
                  inherit globalUsername;
                };
                users.${globalUsername} = {
                  imports = [
                    ./home

                    sops-nix.homeManagerModules.sops
                    catppuccin.homeManagerModules.catppuccin
                  ];
                };
              };
            }
          ];
        };

        # Hostname: KASMWEB-001
        # Description: VMware VM running Kasm Web.
        KASMWEB-001 = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/kasmweb-001

            catppuccin.nixosModules.catppuccin
          ];
        };

        # Hostname: HYPERVISOR-1
        # Description: Hypervisor Node 1
        HYPERVISOR-1 = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/hypervisor-1

            catppuccin.nixosModules.catppuccin
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
          ];
        };

        # Hostname: HYPERVISOR-2
        # Description: Hypervisor Node 2
        HYPERVISOR-2 = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/hypervisor-2

            catppuccin.nixosModules.catppuccin
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
          ];
        };

        # Hostname: HYPERVISOR-3
        # Description: Hypervisor Node 3
        HYPERVISOR-3 = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/hypervisor-3

            catppuccin.nixosModules.catppuccin
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
          ];
        };

        # Hostname: HYPERVISOR-4
        # Description: Hypervisor Node 4
        HYPERVISOR-4 = configNixOS {
          username = globalUsername;
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/hypervisor-4

            catppuccin.nixosModules.catppuccin
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
          ];
        };

      };

      #########################
      # Home Manager
      #########################

      homeConfigurations =
        let
          system = builtins.currentSystem;
        in
        {
          ${globalUsername} = mkHomeConfigurations system;
        };

      #########################
      # Packages
      #########################

      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;

        #home-manager = self.homeConfigurations.${globalUsername}.activationPackage.${system};
      });

      #########################
      # DevShells
      #########################

      devShells = forEachSystem (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};

          shells = {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                (import ./devenv/dotfiles.nix)
              ];
            };
          };
        in
        shells
      );
    };
}
