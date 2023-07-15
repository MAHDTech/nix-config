{
  inputs,
  pkgs,
  pkgsUnstable,
  ...
}:
inputs.devenv.lib.mkShell {
  inherit inputs;
  inherit pkgs;

  modules = [
    {
      # https://devenv.sh/reference/options/

      packages = with pkgs; [
        figlet
        hello

        nixpkgs-fmt
        statix
        nil
        alejandra

        #sops
        #sops-init-gpg-key
        #sops-import-keys-hook
        #ssh-to-age
        #ssh-to-pgp
        #age

        bash
        bash-completion

        python3

        skopeo
      ];

      env = {
        DEVENV_DEVSHELL_ROOT = builtins.toString ./.;
      };

      enterShell = ''
        # Linters
        export HUNSPELL_CONFIG=''${PROJECT_DIR}/.linters/config/hunspell.conf
        export PRETTIER_CONFIG=''${PROJECT_DIR}/.linters/config/.prettierrc.yaml
        export YAMLLINT_CONFIG_FILE=''${PROJECT_DIR}/.linters/config/.yamllint.yml

        figlet ''${PROJECT_SHELL:-Unknown}

        hello \
          --greeting \
          "
          Welcome ''${USER}!

          Shell: ''${PROJECT_SHELL:-Unknown}
          Project: ''${PROJECT_NAME:-Unknown}
          Directory: ''${PROJECT_DIR:-Unknown}
          "

      '';

      pre-commit = {
        default_stages = ["commit"];

        excludes = ["README.md"];

        hooks = {
          # Nix
          alejandra.enable = true;
          nixfmt.enable = false;
          nixpkgs-fmt.enable = false;
          deadnix.enable = false;
          statix.enable = true;

          # GitHub Actions
          actionlint.enable = true;

          # Ansible
          ansible-lint.enable = false;

          # Python
          autoflake.enable = true;
          black.enable = true;
          flake8.enable = true;
          pylint.enable = true;
          ruff.enable = true;

          # Bash
          bats.enable = true;
          shellcheck.enable = true;
          shfmt.enable = true;

          # Rust
          cargo-check.enable = true;
          clippy.enable = true;
          rustfmt.enable = true;

          # Go
          gofmt.enable = true;
          gotest.enable = true;
          govet.enable = true;
          revive.enable = true;
          staticcheck.enable = true;

          # Spelling
          hunspell.enable = false;
          typos.enable = true;

          # Git commit messages
          commitizen.enable = true;

          # Docker
          hadolint.enable = true;

          # Dhall
          dhall-format.enable = true;

          # Markdown
          markdownlint = {
            enable = true;
          };

          mdsh.enable = true;

          # Common
          prettier.enable = true;

          # YAML
          yamllint.enable = true;

          # Terraform
          terraform-format.enable = true;

          # Haskell
          hlint.enable = true;
        };

        settings = {
          deadnix = {
            noUnderscore = true;
          };

          markdownlint = {
            config = {
              # No hard tabs allowed.
              no-hard-tabs = true;

              # Unordered list intendation.
              MD007 = {
                indent = 4;
              };

              # Training spaces
              MD009 = {
                br_spaces = 2;
              };

              # Line length
              MD013 = false;

              # Inline HTML
              MD033 = false;

              # List marker spaces.
              # Disabled for use with prettier.
              MD030 = false;
            };
          };

          prettier = {
            output = "check";
            write = true;
          };

          yamllint = {
          };
        };
      };

      devcontainer = {
        enable = true;

        settings = {
          customizations = {
            vscode = {
              extensions = [
                "exiasr.hadolint"
                "nhoizey.gremlins"
                "esbenp.prettier-vscode"
                "github.copilot"
                "github.vscode-github-actions"
                "kamadorueda.alejandra"
                "ms-azuretools.vscode-docker"
                "pinage404.nix-extension-pack"
                "redhat.vscode-yaml"
                "timonwong.shellcheck"
                "tuxtina.json2yaml"
                "vscodevim.vim"
                "wakatime.vscode-wakatime"
              ];
            };
          };
        };
      };

      devenv = {
        flakesIntegration = true;
        #warnOnNewVersion = true;
      };

      difftastic.enable = true;

      #hosts = {"example.com" = "1.1.1.1";};

      languages = {
        cue = {
          enable = true;
          package = pkgs.cue;
        };

        gawk = {enable = true;};

        go = {
          enable = false;
          package = pkgs.go;
        };

        nix = {enable = true;};

        python = {
          enable = true;
          package = pkgs.python3;

          poetry = {
            enable = true;
            package = pkgs.poetry;
          };

          venv = {enable = true;};
        };

        rust = {
          enable = true;
          channel = "stable";
        };

        terraform = {
          enable = false;
          package = pkgs.terraform;
        };
      };

      starship = {
        enable = true;
        package = pkgs.starship;
        config = {
          enable = true;
          path = "/home/$USER/.config/starship.toml";
        };
      };
    }
  ];
}
