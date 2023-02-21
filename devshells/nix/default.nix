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

        bash
        bash-completion
      ];

      env = {
        USERNAME = username;
        DEVENV_DEVSHELL_NAME = "nix";

        DEVENV_DEVSHELL_ROOT = builtins.toString ./.;
      };

      enterShell = ''

        figlet $DEVENV_DEVSHELL

        hello \
          --greeting \
          "
          Hello $USERNAME!

          Shell: \$\{DEVENV_DEVSHELL:-Unknown\}
          Project: \$\{PROJECT_NAME:-Unknown\}
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
          path = "/home/\$\{USERNAME\}/.config/starship.toml";
        };
      };
    }
  ];
}
