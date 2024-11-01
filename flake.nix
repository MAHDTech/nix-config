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
      # TODO: Revert when the rolling branch is updated.
      # https://github.com/cachix/devenv-nixpkgs/issues/2
      #owner = "cachix";
      #repo = "devenv-nixpkgs";
      #ref = "rolling";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
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
      owner = "GermanBread";
      repo = "declarative-flatpak";
      ref = "dev";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm = {
      type = "github";
      owner = "wez";
      repo = "wezterm";
      ref = "main";
      flake = true;
      dir = "nix";
    };

    catppuccin = {
      type = "github";
      owner = "catppuccin";
      repo = "nix";
      ref = "main";
      flake = true;
    };

    ags = {
      type = "github";
      owner = "Aylur";
      repo = "ags";
      ref = "main";
      flake = true;
    };

    matugen = {
      type = "github";
      owner = "InioX";
      repo = "matugen";
      ref = "v2.2.0";
      flake = true;
    };
  };

  outputs = {
    catppuccin,
    devenv,
    flatpaks,
    home-manager,
    nixos-cosmic,
    nixos-hardware,
    nixpkgs,
    nixpkgs-unstable,
    self,
    sops-nix,
    systems,
    ...
  } @ inputs: let
    # Whoami
    globalUsername = "mahdtech";

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It's perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    globalStateVersion = "23.11";

    #########################
    # Systems functions
    #########################

    forEachSystem = nixpkgs.lib.genAttrs (import systems);

    #########################
    # Packages functions
    #########################

    pkgsImportSystem = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

    _pkgsImportSystemUnstable = system:
      import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

    #########################
    # NixOS functions
    #########################

    configNixOS = {
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

        modules =
          [
            sops-nix.nixosModules.sops
          ]
          ++ extraModules;
      };

    #########################
    # Home Manager functions
    #########################

    # Home Manager (standalone)
    mkHomeConfigurations = system:
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          ./home
          sops-nix.homeManagerModules.sops
        ];
        extraSpecialArgs = {
          inherit inputs;
          inherit globalStateVersion;
          inherit globalUsername;
          inherit system;
        };
      };
    # TODO: Fix this, missing 'lib'
    # Home Manager (NixOS module)
    #mkHomeManagerConfigurationsNixOS = {
    #  username,
    #  inputs,
    #  globalStateVersion,
    #}:
    #  home-manager.nixosModules.home-manager {
    #    home-manager = {
    #      useGlobalPkgs = true;
    #      useUserPackages = true;
    #      extraSpecialArgs = {
    #        inherit inputs;
    #        inherit globalStateVersion;
    #        inherit username;
    #      };
    #      users.${username} = {
    #        imports = [
    #          ./home
    #          sops-nix.homeManagerModules.sops
    #        ];
    #      };
    #    };
    #  };
  in {
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
          # Enable Catppuccin theme.
          catppuccin.nixosModules.catppuccin

          ./nixos/hosts/template
          {system.stateVersion = globalStateVersion;}
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
          # Enable Catppuccin theme.
          catppuccin.nixosModules.catppuccin

          ./nixos/hosts/nixos-1
          {system.stateVersion = globalStateVersion;}
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
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-ssd
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel

          # Enable COSMIC desktop environment.
          nixos-cosmic.nixosModules.default

          # Enable Catppuccin theme.
          catppuccin.nixosModules.catppuccin

          # Enable declarative flatpak support.
          flatpaks.nixosModules.default

          ./nixos/hosts/nuc
          {system.stateVersion = globalStateVersion;}

          #(
          #  mkHomeManagerConfigurationsNixOS {
          #    username = globalUsername;
          #    inherit inputs globalStateVersion;
          #    lib = pkgs.lib;
          #  }
          #)

          home-manager.nixosModules.home-manager
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
    };

    #########################
    # Home Manager
    #########################

    homeConfigurations = let
      system = builtins.currentSystem;
    in {
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

    devShells = forEachSystem (system: let
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
      shells);
  };
}
