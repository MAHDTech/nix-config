{
  pkgs,
  config,
  lib,
  ...
}:

let
  packages = with pkgs; [
    hello
  ];

  devPackages = with pkgs; [
    docker-client
    figlet
    #go-tools
    #golangci-lint
    nil
    nix
    #pulumi-bin # bundled with plugins.
    #pulumictl
    #sshuttle
    #trivy
    #yq-go
  ];

in
{
  name = "dotfiles";

  env = {
    PROJECT = config.name;
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

  packages = packages ++ lib.optionals (!config.container.isBuilding) devPackages;

  enterShell = ''
    figlet -f starwars $PROJECT

    hello --greeting="Hello ''${USER:-user}, welcome to the $PROJECT project!"
  '';

  difftastic = {
    enable = true;
  };

  languages = {
    nix = {
      enable = true;
    };

    shell = {
      enable = true;
    };

    go = {
      enable = false;
    };

    opentofu = {
      enable = false;
    };
  };

  git-hooks = {
    excludes = [
      ".cache"
      ".devenv"
      ".direnv"
      "vendor"
      "home/files/ags/config/.*"
    ];
    hooks = {
      actionlint.enable = true;
      check-json.enable = true;
      check-merge-conflicts.enable = true;
      check-shebang-scripts-are-executable.enable = true;
      check-symlinks.enable = true;
      check-yaml.enable = true;
      commitizen.enable = true;
      convco.enable = true;
      deadnix = {
        enable = true;
        settings = {
          noUnderscore = true;
        };
      };
      dialyzer.enable = true;
      editorconfig-checker.enable = true;
      gofmt.enable = true;
      golangci-lint.enable = true;
      golines.enable = true;
      gotest.enable = true;
      govet.enable = true;
      gptcommit.enable = true;
      markdownlint = {
        enable = true;
        settings = {
          configuration = {
            MD033 = false;
            MD007 = {
              ul_indent = 4;
            };
            MD013 = {
              line_length = 180;
            };
          };
        };
      };
      mixed-line-endings.enable = true;
      nixfmt-rfc-style.enable = true;
      pre-commit-hook-ensure-sops.enable = true;
      prettier = {
        enable = true;
        settings = {
          configPath = ".prettierrc.yaml";
        };
      };
      pretty-format-json = {
        enable = true;
        args = [
          "--autofix"
        ];
      };
      revive = {
        enable = true;
        fail_fast = false;
      };
      ripsecrets.enable = true;
      shellcheck = {
        enable = true;
        args = [
          "--external-sources"
        ];
      };
      shfmt.enable = true;
      staticcheck.enable = true;
      statix.enable = true;
      trufflehog.enable = false;
      trim-trailing-whitespace.enable = true;
      typos.enable = true;
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
