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
  };

  outputs = {
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
      };

    _pkgsImportSystemUnstable = system:
      import nixpkgs-unstable {
        inherit system;
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
    in {
      default = devenv.lib.mkShell {
        inherit inputs;
        inherit pkgs;

        modules = [
          # https://devenv.sh/reference/options/
          {
            name = "dotfiles";

            env = {
              PROJECT = "dotfiles";
            };

            dotenv = {
              enable = true;
              disableHint = false;
            };

            cachix = {
              enable = true;
              push = [
                "salt-labs"
              ];
              pull = [
                "salt-labs"
              ];
            };

            packages = with pkgs; [
              figlet
            ];

            enterShell = ''
              figlet -f starwars $PROJECT

              echo Hello $USER, welcome to the $PROJECT project
            '';

            difftastic = {
              enable = true;
            };

            pre-commit = {
              default_stages = [
                "pre-commit"
              ];

              hooks = {
                alejandra = {
                  enable = true;
                };

                beautysh = {
                  enable = false;
                };

                check-json = {
                  enable = true;
                };

                check-shebang-scripts-are-executable = {
                  enable = true;
                };

                check-symlinks = {
                  enable = true;
                };

                check-yaml = {
                  enable = true;
                };

                convco = {
                  enable = true;
                };

                cspell = {
                  enable = false;
                };

                deadnix = {
                  enable = true;
                  settings = {
                    noUnderscore = true;
                  };
                };

                dialyzer = {
                  enable = true;
                };

                editorconfig-checker = {
                  enable = true;
                };

                markdownlint = {
                  enable = true;
                  settings = {
                    configuration = {
                      MD013 = {
                        line_length = 200;
                      };
                      MD033 = false;
                    };
                  };
                };

                nil = {
                  enable = false;
                };

                pre-commit-hook-ensure-sops = {
                  enable = true;
                };

                prettier = {
                  enable = true;
                };

                pretty-format-json = {
                  enable = false;
                };

                ripsecrets = {
                  enable = true;
                  excludes = [
                  ];
                };

                shellcheck = {
                  enable = true;
                };

                shfmt = {
                  enable = true;
                };

                trim-trailing-whitespace = {
                  enable = true;
                };

                typos = {
                  enable = true;
                  settings = {
                    configPath = ".typos.toml";
                  };
                };

                yamllint = {
                  enable = true;
                  settings = {
                    configuration = ''
                      extends: relaxed
                      rules:
                        line-length: disable
                        indentation: enable
                    '';
                  };
                };
              };
            };

            starship = {
              enable = true;
              config = {
                enable = false;
              };
            };

            devcontainer = {
              enable = true;
              settings = {
                customizations = {
                  vscode = {
                    extensions = [
                      "arrterian.nix-env-selector"
                      "esbenp.prettier-vscode"
                      "github.vscode-github-actions"
                      "jnoortheen.nix-ide"
                      "johnpapa.vscode-peacock"
                      "kamadorueda.alejandra"
                      "mkhl.direnv"
                      "nhoizey.gremlins"
                      "pinage404.nix-extension-pack"
                      "redhat.vscode-yaml"
                      "streetsidesoftware.code-spell-checker"
                      "tekumura.typos-vscode"
                      "timonwong.shellcheck"
                      "tuxtina.json2yaml"
                      "vscodevim.vim"
                      "wakatime.vscode-wakatime"
                      "yzhang.markdown-all-in-one"
                    ];
                  };
                };
              };
            };

            enterTest = ''
              echo "Running devenv tests..."
            '';
          }
        ];
      };
    });
  };
}
