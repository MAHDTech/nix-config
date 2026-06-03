{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let

  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  unstablePkgs = with pkgsUnstable; [
  ];

  packages = with pkgs; [
    hello
    pkg-config
    openssl
  ];

  devPackages = with pkgs; [
    figlet
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
    enable = false;
  };

  packages = packages ++ unstablePkgs ++ lib.optionals (!config.container.isBuilding) devPackages;

  enterShell = ''
    figlet -f slant $PROJECT

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
      enable = true;
    };

    opentofu = {
      enable = false;
    };
  };

  git-hooks = {
    excludes = [
      ".*\\.drawio$"
      "^\\.cache(/.*)?$"
      "^\\.devenv(/.*)?$"
      "^\\.direnv(/.*)?$"
      "^\\.git(/.*)?$"
      "^docs/agents/.*"
      "^nixos/hosts/.*/files/.*$"
      "^vendor(/.*)?$"
    ];
    hooks = {
      actionlint.enable = true;
      check-json.enable = true;
      check-merge-conflicts.enable = true;
      check-shebang-scripts-are-executable = {
        excludes = [
          ".*\\.rs$"
        ];
        enable = true;
      };
      check-symlinks.enable = true;
      check-yaml.enable = true;
      commitizen.enable = true;
      convco.enable = true;
      clippy.enable = true;
      cargo-check.enable = true;
      custom-cargo-test = {
        enable = true;
        name = "cargo-test";
        description = "Run cargo test";
        entry = "cargo test";
        pass_filenames = false;
        types_or = [ "rust" ];
      };
      deadnix = {
        enable = true;
        settings = {
          noUnderscore = true;
        };
      };
      cspell = {
        enable = true;
        package = pkgs.cspell;
      };
      dialyzer.enable = true;
      editorconfig-checker = {
        enable = true;
      };
      gofmt.enable = true;
      golangci-lint = {
        enable = true;
        excludes = [ "^scripts/hacks/" ];
      };
      golines.enable = true;
      gotest.enable = true;
      govet.enable = true;
      gptcommit.enable = true;
      markdownlint = {
        enable = false;
        package = pkgs.markdownlint-cli;
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
      nixfmt.enable = true;
      prettier = {
        enable = true;
        package = pkgs.prettier;
        settings = {
          configPath = ".prettierrc.yaml";
        };
      };
      revive = {
        enable = true;
        fail_fast = false;
        excludes = [ "^scripts/hacks/" ];
      };
      ripsecrets.enable = true;
      shellcheck = {
        enable = true;
        args = [
          "--external-sources"
        ];
      };
      shfmt.enable = true;
      staticcheck = {
        enable = true;
        excludes = [ "^scripts/hacks/" ];
      };
      statix.enable = true;
      trufflehog.enable = false;
      trim-trailing-whitespace.enable = true;
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
