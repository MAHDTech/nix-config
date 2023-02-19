{ username, inputs, pkgs, ...}:

inputs.devenv.lib.mkShell {

  inherit inputs;
  inherit pkgs;

  modules = [

    {

      # https://devenv.sh/reference/options/

      packages = with pkgs; [

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

        hello --greeting "Dev Shell: Default"

      '';

      pre-commit = {

        default_stages = [
          "commit"
        ];

        excludes = [
          "README.md"
        ];

        hooks = {

          actionlint.enable = true;
          #alejandra.enable = true;
          #ansible-lint.enable = true;
          #autoflake.enable = true;
          #bats.enable = true;
          #black.enable = true;
          #cargo-check.enable = true;
          #clippy.enable = true;
          #commitizen.enable = true;
          #deadnix.enable = true;
          #dhall-format.enable = true;
          #flake8.enable = true;
          #gofmt.enable = true;
          #gotest.enable = true;
          #govet.enable = true;
          #hadolint.enable = true;
          #hlint.enable = true;
          #hunspell.enable = true;
          #markdownlint.enable = true;
          #mdsh.enable = true;
          #nixfmt.enable = true;
          #nixpkgs-fmt.enable = true;
          #prettier.enable = true;
          #pylint.enable = true;
          #revive.enable = true;
          #ruff.enable = true;
          #rustfmt.enable = true;
          #shellcheck.enable = true;
          #shfmt.enable = true;
          #staticcheck.enable = true;
          #statix.enable = true;
          #terraform-format.enable = true;
          #typos.enable = true;
          #yamllint.enable = true;

        };

      };

      devcontainer.enable = true;

      devenv = {

        flakesIntegration = true;
        #warnOnNewVersion = true;

      };

      difftastic.enable = true;

      hosts = {

        "example.com" = "1.1.1.1";

      };

      languages = {

        cue = {
          enable = true;
          package = pkgs.cue;
        };

        gawk = {
          enable = true;
        };

        go = {
          enable = true;
          package = pkgs.go;
        };

        nix = {
          enable = true;
        };

        python = {
          enable = true;
          package = pkgs.python3;

          poetry = {
            enable = true;
            package = pkgs.poetry;
          };

          venv = {
            enable = true;
          };
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
                headers = {
                  Content-Type = "text/plain";
                };
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
                jsonBody = {
                  key = "value";
                };
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