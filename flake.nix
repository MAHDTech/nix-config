{
  description = "NixOS and Home Manager configuration";

  nixConfig = {
    extra-substituters = ''
      https://cache.nixos.org
      https://cosmic.cachix.org/
      https://devenv.cachix.org
      https://hyprland.cachix.org/
      https://mahdtech.cachix.org
      https://salt-labs.cachix.org
    '';
    extra-trusted-public-keys = "
      cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=
      devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
      hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=
      mahdtech.cachix.org-1:LtqGFUwyvUqRrl+LijURnBwkwQLwRO52dbDfrYkjWTg=
      salt-labs.cachix.org-1:9lBlhm9rPAHrb1GXnclFomAHsnj3kV+4DyJspy/nQlw=
    ";
    warn-dirty = true;
  };

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "release-25.05";
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
      ref = "release-25.05";
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

    #nixos-cosmic = {
    #  type = "github";
    #  owner = "lilyinstarlight";
    #  repo = "nixos-cosmic";
    #  ref = "main";
    #  flake = true;
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    flatpaks = {
      type = "github";
      owner = "in-a-dil-emma";
      repo = "declarative-flatpak";
      ref = "latest";
      flake = true;
    };

    catppuccin = {
      type = "github";
      owner = "catppuccin";
      repo = "nix";
      ref = "release-1.x";
      flake = true;
    };

    #musnix = {
    #  type = "github";
    #  owner = "musnix";
    #  repo = "musnix";
    #  ref = "master";
    #  flake = true;
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    impermanence = {
      type = "github";
      owner = "nix-community";
      repo = "impermanence";
      ref = "master";
      flake = true;
    };

  };

  outputs =
    {
      catppuccin,
      devenv,
      flatpaks,
      home-manager,
      #musnix,
      #nixos-cosmic,
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

      # Are we running in GitHub Actions?
      inGitHubActions = builtins.getEnv "GITHUB_ACTIONS" == "true";

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
          config = {
            allowUnfree = true;
            # Accept the JoyPixels license for font use.
            joypixels.acceptLicense = true;
          };
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
          ]
          ++ extraModules;
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
            home-manager.nixosModules.home-manager
            sops-nix.homeManagerModules.sops
          ];
          extraSpecialArgs = {
            inherit inputs;
            inherit globalStateVersion;
            inherit globalUsername;
            inherit system;
            inherit inGitHubActions;
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
            flatpaks.nixosModules.default
            home-manager.nixosModules.home-manager
            #musnix.nixosModules.default
            #nixos-cosmic.nixosModules.default
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
                  inherit inGitHubActions;
                }
                // (import ./nixos/hosts/nuc/home-manager/syncthing.nix);
                users.${globalUsername} = {
                  imports = [
                    ./home

                    catppuccin.homeManagerModules.catppuccin
                    sops-nix.homeManagerModules.sops
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
            flatpaks.nixosModules.default
            home-manager.nixosModules.home-manager
            #musnix.nixosModules.default
            #nixos-cosmic.nixosModules.default
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
                  inherit inGitHubActions;
                }
                // (import ./nixos/hosts/jons/home-manager/syncthing.nix);
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

        # Hostname: OPI-001
        # Description: Orange PI 5 Pro 1
        OPI-001 = configNixOS {
          username = globalUsername;
          system = "aarch64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/opi-001

            catppuccin.nixosModules.catppuccin
          ];
        };

        # Hostname: ZENBOOK
        # Description: ASUS Zenbook A14 Snapdragon X Elite 32GB RAM (UX3407R)
        ZENBOOK = configNixOS {
          username = globalUsername;
          system = "aarch64-linux";

          specialArgs = {
            inherit inputs;
          };

          extraModules = [
            { system.stateVersion = globalStateVersion; }

            ./nixos/hosts/zenbook

            catppuccin.nixosModules.catppuccin
            flatpaks.nixosModules.default
            home-manager.nixosModules.home-manager
            {

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  inherit globalStateVersion;
                  inherit globalUsername;
                  inherit inGitHubActions;
                }
                // (import ./nixos/hosts/zenbook/home-manager/syncthing.nix);
                users.${globalUsername} = {
                  imports = [
                    ./home

                    catppuccin.homeManagerModules.catppuccin
                    sops-nix.homeManagerModules.sops
                  ];
                };
              };
            }
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
