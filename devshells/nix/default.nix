{
  inputs,
  pkgs,
  ...
}:
inputs.devenv.lib.mkShell {
  inherit inputs;
  inherit pkgs;

  #sopsPGPKeysDirs = [
  #  "${toString ./.}/secrets/keys/hosts"
  #  "${toString ./.}/secrets/keys/users"
  #];

  #nativeBuildInputs = [
  #  (pkgs.callPackage sops-nix {}).sops-import-keys-hook
  #];

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

        bash
        bash-completion
      ];

      env = {
        PROJECT_SHELL = "nix";

        DEVENV_DEVSHELL_ROOT = builtins.toString ./.;
      };

      enterShell = ''

        figlet ''${PROJECT_SHELL:-Unknown}

        hello \
          --greeting \
          "
          Welcome ''${USER}!

          Shell: ''${PROJECT_SHELL:-Unknown}
          Project: ''${PROJECT_NAME:-Unknown}
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
          deadnix.enable = true;
          statix.enable = true;

          # GitHub Actions
          actionlint.enable = true;

          # Bash
          bats.enable = true;
          shellcheck.enable = true;
          shfmt.enable = true;

          # Spelling
          hunspell.enable = false;
          typos.enable = false;

          # Git commit messages
          commitizen.enable = true;

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
            relaxed = false;
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
        nix = {enable = true;};
      };

      services = {
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
