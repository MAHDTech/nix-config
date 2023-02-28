{
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

        bash
        bash-completion

        python3
      ];

      env = {
        DEVENV_DEVSHELL_ROOT = builtins.toString ./.;
      };

      enterShell = ''

        # Source the virtual environment
        source $VIRTUAL_ENV/bin/activate

        pip install \
          --requirement $DEVENV_DEVSHELL_ROOT/requirements.txt

        figlet ''${PROJECT_SHELL:-Unknown}

        hello \
          --greeting \
          "
          Welcome ''${USER}!

          Shell: $DEVENV_DEVSHELL
          Project: $PROJECT_NAME
          "

      '';

      pre-commit = {
        default_stages = ["commit"];

        excludes = ["README.md"];

        hooks = {
          # GitHub Actions
          actionlint.enable = true;

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

          # Spelling
          hunspell.enable = false;
          typos.enable = false;

          # Git commit messages
          commitizen.enable = true;

          # Docker
          hadolint.enable = true;

          # Markdown
          markdownlint.enable = true;
          mdsh.enable = true;

          # Common
          prettier.enable = true;

          # YAML
          yamllint.enable = true;
        };

        settings = {
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

          yamllint = {
            configPath = builtins.toString (./. + "/.linters/yaml-lint.yaml");
          };
        };
      };

      devcontainer.enable = false;

      devenv = {
        flakesIntegration = true;
        #warnOnNewVersion = true;
      };

      difftastic.enable = true;

      hosts = {"example.com" = "1.1.1.1";};

      languages = {
        python = {
          enable = true;
          package = pkgs.python3;

          poetry = {
            enable = false;
            package = pkgs.poetry;
          };

          venv = {enable = true;};
        };
      };

      services = {};

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
