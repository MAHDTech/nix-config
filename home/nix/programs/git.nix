{
  pkgs,
  config,
  ...
}:
{
  home.packages = with pkgs; [
    bfg-repo-cleaner
    difftastic
    gh
    git
    git-filter-repo
    git-lfs
    jujutsu
  ];

  home.file = {
    "allowed-signers" = {
      target = "${config.home.homeDirectory}/.config/git/allowed-signers";
      executable = false;
      text = ''
        MAHDTech ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU
      '';
    };
  };

  programs = {

    # Use difftastic for the difftool
    difftastic = {
      enable = true;
      git.enable = true;
      git.diffToolMode = true;
      options = {
        background = "dark";
        color = "always";
        display = "side-by-side";
      };
    };

    # Use delta for the pager
    delta = {
      enable = true;
      options = {
        features = "decorations";
        navigate = true;
        light = false;
        side-by-side = true;
      };
    };

    git = {
      enable = true;

      package = pkgs.git;

      signing = {
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU";
        signByDefault = true;
      };

      settings = {
        user = {
          name = "MAHDTech";
          email = "MAHDTech@saltlabs.tech";
        };

        alias = {
          # List any files which have changed since the REVIEW_BASE
          files = ''!git diff --name-only $(git merge-base HEAD "$REVIEW_BRANCH")'';

          # List any files with a diff stat
          stat = ''!git diff --stat $(git merge-base HEAD "$REVIEW_BRANCH")'';

          # Lazy review with vim of all files changed
          review = ''
            !vim -p $(git files) +"tabdo Gdiff $REVIEW_BRANCH" +"let g:gitgutter_diff_base = '$REVIEW_BRANCH'"
          '';

          # Lazy review with vim of a single file provided
          reviewone = ''
            !vim -p +"tabdo Gdiff $REVIEW_BRANCH" +"let g:gitgutter_diff_base = '$REVIEW_BRANCH'"
          '';

          # Use external diff tool
          dft = ''difftool'';

          # Reset file permissions only
          reset-permissions = ''
            !git diff -p -R --no-ext-diff --no-color --diff-filter=M | grep -E "^(diff|(old|new) mode)" --color=never | git apply
          '';
        };
        # [core]
        core = {
          # HACK: Use ssh from Windows for WSL.
          #sshCommand = "ssh.exe";

          autocrlf = "input";
          editor = "vim";
          filemore = true;

          # Managed with devenv githooks.
          #hooksPath = ".githooks" ;
        };

        # [credential]
        #  git help -a | grep credential-
        credential = {
          helper = "cache";
        };

        # [color]
        color = {
          ui = true;

          branch = {
            current = "yellow reverse";
            local = "yellow";
            remote = "green";
          };

          diff = {
            meta = "yellow bold";
            frag = "magenta bold";
            old = "red bold";
            new = "green bold";
          };

          status = {
            added = "yellow";
            changed = "green";
            untracked = "red";
          };
        };

        # [gpg]
        gpg = {
          format = "ssh";
          ssh = {
            # Common
            allowedSignersFile = "~/.config/git/allowed-signers";
            # WSL
            #program = "/mnt/c/Users/MAHDTech/AppData/Local/1Password/app/8/op-ssh-sign-wsl";
            # NixOS and Crostini.
            program = "${pkgs._1password-gui}/bin/op-ssh-sign";
          };
        };

        # [interactive]
        interactive = {
        };

        # [diff]
        diff = {
          colorMoved = "zebra";
        };

        # [init]
        init = {
          defaultBranch = "trunk";
          excludesfile = "~/.config/git/ignore";
        };

        # [filter]
        filter = {
          lfs = {
            clean = "git-lfs clean -- %f";
            smudge = "git-lfs smudge -- %f";
            process = "git-lfs filter-process";
            required = true;
          };
        };

        # [pager]
        pager = {
          difftool = true;
        };

        # [fetch]
        fetch = {
          prune = true;
        };

        # [push]
        push = {
          default = "current";
        };

        # [pull]
        pull = {
          rebase = true;
        };

        # [http]
        http = {
          sslVerify = true;
        };

        # [tag]
        tag = {
          forceSignAnnotated = true;
        };

        # [url]
        url = {
          "ssh://git@github.com" = {
            insteadOf = "https://github.com";
          };

          "ssh://git@gitlab.com" = {
            insteadOf = "https://gitlab.com";
          };

          "ssh://git@bitbucket.org" = {
            insteadOf = "https://bitbucket.org";
          };
        };
      };

      includes = [
        # NOTE: gitdir/i to ignorecase

        # Codespaces
        {
          condition = "gitdir/i:**/vsonline/workspace/";
          contentSuffix = "gitconfig_codespaces";
          contents = {
            user = {
              name = "MAHDTech";
              email = "MAHDTech@saltlabs.tech";
            };
          };
        }

        # GitHub (MAHDTech)
        {
          condition = "gitdir/i:**/projects/github/mahdtech/";
          contentSuffix = "gitconfig_github_mahdtech";
          contents = {
            user = {
              name = "MAHDTech";
              email = "MAHDTech@saltlabs.tech";
            };
          };
        }

        # GitHub (Salt Labs)
        {
          condition = "gitdir/i:**/projects/github/salt-labs/";
          contentSuffix = "gitconfig_github_salt-labs";
          contents = {
            user = {
              name = "MAHDTech";
              email = "MAHDTech@saltlabs.tech";
            };
          };
        }

        # GitHub (Irken Empire)
        {
          condition = "gitdir/i:**/projects/github/irken-empire/";
          contentSuffix = "gitconfig_github_irken-empire";
          contents = {
            user = {
              name = "Operation Impending Doom";
              email = "doom@irkenempire.tech";
            };
          };
        }

        # GitLab (MAHDTech)
        {
          condition = "gitdir/i:**/projects/gitlab/mahdtech/";
          contentSuffix = "gitconfig_gitlab_mahdtech";
          contents = {
            user = {
              name = "MAHDTech";
              email = "MAHDTech@saltlabs.tech";
            };
          };
        }

        # Work
        {
          condition = "gitdir/i:**/projects/work/";
          contentSuffix = "gitconfig_work";
          contents = {
            user = {
              name = "Matthew Duncan";
              email = "matthew.duncan@mahdtech.com";
            };
          };
        }

        # IntelliScope CloudForge
        {
          condition = "gitdir/i:**/projects/work/cloudforge/";
          contentSuffix = "gitconfig_work_cloudforge";
          contents = {
            user = {
              name = "Dev 02";
              email = "dev_02@example.com";
              signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAeVzPrwBuCpiyUYeUErStSm+D7yhP6VHNnkPsuj15Cp";
            };
          };
        }
      ];

      ignores = [
        # VS Code / VS Codium
        "!.vscode/"
        "!.vscode-oss/"
        "!.vscode/settings.json"
        "!.vscode-oss/settings.json"
        ".vscode/**"
        ".vscode-oss/**"

        # IntelliJ
        "*.iml"
        "*.ipr"
        "*.iws"
        ".idea/"

        # Wakatime
        #"*.wakatime*"
        #".wakatime-project"

        # Node
        "npm-debug.log"

        # Windows
        "Thumbs.db"

        # Compiled
        "*.com"
        "*.class"
        "*.dll"
        "*.exe"
        "*.o"
        "*.so"

        # WebStorm
        ".idea/"

        # vi
        "*~"

        # Packages
        "*.7z"
        "*.dmg"
        "*.gz"
        "*.iso"
        "*.jar"
        "*.rar"
        "*.tar"
        "*.zip"

        # Logs and databases
        "*.log"
        "*.sql"
        "*.sqlite"

        # OS generated files
        ".DS_Store"
        ".DS_Store?"
        "._*"
        ".Spotlight-V100"
        ".Trashes"
        "ehthumbs.db"
        "Thumbs.db"

        "secring.*"

        # SSH keys
        ".ssh/id_rsa"
        ".ssh/id_rsa.pub"

        # Golang
        "!vendor/"
        "!vendor/**"

        # GPG
        ".gnupg"

        # Python
        "*.py[cod]"

        # Unsorted
        "*.pdf"
        "*.aux"
        "*.lof"
        "*.lot"
        "*.fls"
        "*.out"
        "*.toc"
        "*.fmt"
        "*.cb"
        "*.cb2"
        "*.dvi"
        "*-converted-to.*"
        "*.fdb_latexmk"
        "*.synctex.gz"
        "*.bbl"
        "*.bcf"
        "*.blg"
        "*-blx.aux"
        "*-blx.bib"
        "*.run.xml"
        "*.nav"
        "*.pre"
        "*.snm"
        "*.vrb"
        "*.lol"
        ".fuse_hidden*"
        ".Trash-*"
        ".nfs*"
        "[._]*.s[a-v][a-z]"
        "[._]*.sw[a-p]"
        "[._]s[a-v][a-z]"
        "[._]sw[a-p]"
        "Session.vim"
        ".netrwhist"
        ".viminfo"
        "*~"
        "tags"
        "*.class"
        "*.log"
        "*.ctxt"
        ".mtj.tmp/"
        "*.jar"
        "*.war"
        "*.ear"
        "*.zip"
        "*.tar.gz"
        "*.rar"
        "hs_err_pid*"
        "target/"
      ];
    };
  };
}
