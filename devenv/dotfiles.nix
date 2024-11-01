{pkgs, ...}:
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
