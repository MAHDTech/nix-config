{
  username,
  inputs,
  pkgs,
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

        sops
        #sops-init-gpg-key
        #sops-import-keys-hook
        ssh-to-age
        ssh-to-pgp
        age
      ];

      env = {
        USERNAME = username;
        DEVENV_DEVSHELL = "default";
      };

      enterShell = ''

        figlet $DEVENV_DEVSHELL

        hello \
          --greeting \
          "Hello $USERNAME, welcome to the $DEVENV_DEVSHELL development shell!"

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
          typos.enable = false;

          # Git commit messages
          commitizen.enable = true;

          # Docker
          hadolint.enable = true;

          # Dhall
          dhall-format.enable = true;

          # Markdown
          markdownlint.enable = true;
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
      };

      devcontainer.enable = true;

      devenv = {
        flakesIntegration = true;
        #warnOnNewVersion = true;
      };

      difftastic.enable = true;

      hosts = {"example.com" = "1.1.1.1";};

      languages = {
        cue = {
          enable = true;
          package = pkgs.cue;
        };

        gawk = {enable = true;};

        go = {
          enable = true;
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
          version = "stable";
        };

        terraform = {
          enable = true;
          package = pkgs.terraform;
        };
      };

      services = {
        wiremock = {
          enable = false;
          port = 8080;
          verbose = true;
          mappings = [
            {
              name = "path";
              request = {
                method = "GET";
                url = "/path";
              };
              response = {
                status = 200;
                body = "OK!";
              };
            }
            {
              name = "body";
              request = {
                method = "GET";
                url = "/body";
              };
              response = {
                body = "This is text in the response body";
                headers = {Content-Type = "text/plain";};
                status = 200;
              };
            }
            {
              name = "json";
              request = {
                method = "GET";
                url = "/json";
              };
              response = {
                jsonBody = {key = "value";};
                status = 200;
              };
            }
          ];
        };
      };

      starship = {
        enable = true;
        package = pkgs.starship;
        config = {
          enable = false;
          path = "/home/${inputs.devenv.config.env.USERNAME}/.config/starship.toml";
        };
      };
    }
  ];
}
