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

      packages = with pkgs; [figlet hello];

      env = {
        USERNAME = username;
        DEVENV_DEVSHELL = "salt";

        DEVENV_DEVSHELL_ROOT = builtins.toString ./.;
      };

      enterShell = ''

        figlet $DEVENV_DEVSHELL

        hello \
          --greeting \
          "Hello $USERNAME, welcome to the $DEVENV_DEVSHELL development shell!"

        #pip install --requirements $DEVENV_DEVSHELL_ROOT/requirements.txt

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
          enable = false;
          path = "/home/${inputs.devenv.config.env.USERNAME}/.config/starship.toml";
        };
      };
    }
  ];
}
