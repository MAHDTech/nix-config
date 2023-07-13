{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs; [git git-lfs gh git-filter-repo bfg-repo-cleaner diff-so-fancy] ++ unstablePkgs;

  programs.git = {
    enable = true;

    package = pkgs.git;

    userName = "MAHDTech";
    userEmail = "MAHDTech@saltlabs.tech";

    signing = {
      key = "0x3E520D84C0F43391";
      signByDefault = true;
    };

    aliases = {
      # List any files which have changed since the REVIEW_BASE
      files = ''!git diff --name-only $(git merge-base HEAD "$REVIEW_BRANCH")'';

      # List any files with a diff stat
      stat = ''!git diff --stat $(git merge-base HEAD "$REVIEW_BRANCH")'';

      # Lazy review with vim of all files changed
      review = ''
        !vim -p $(git files) +"tabdo Gdiff $REVIEW_BRANCH" +"let g:gitgutter_diff_base = '$REVIEW_BRANCH'"'';

      # Lazy review with vim of a single file provided
      reviewone = ''
        !vim -p +"tabdo Gdiff $REVIEW_BRANCH" +"let g:gitgutter_diff_base = '$REVIEW_BRANCH'"'';
    };

    extraConfig = {
      # [core]
      core = {
        autocrlf = "input";
        editor = "vim";
        filemore = true;

        # Managed with devenv githooks.
        #hooksPath = ".githooks" ;

        pager = "diff-so-fancy | less --tabs=4 -RFX";
      };

      # [credential]
      #  git help -a | grep credential-
      credential = {helper = "cache";};

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

      # [interactive]
      interactive = {
        diffFilter = "diff-so-fancy --patch";
      };

      # [diff]
      diff = {colorMoved = "zebra";};

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

      # [fetch]
      fetch = {prune = true;};

      # [push]
      push = {default = "current";};

      # [pull]
      pull = {rebase = true;};

      # [http]
      http = {sslVerify = true;};

      # [tag]
      tag = {forceSignAnnotated = true;};

      # [url]
      url = {
        "ssh://git@github.com" = {insteadOf = "https://github.com";};

        "ssh://git@gitlab.com" = {insteadOf = "https://gitlab.com";};

        "ssh://git@bitbucket.org" = {insteadOf = "https://bitbucket.org";};
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
    ];

    ignores = [
      # VS Code / VS Codium
      ".vscode/"
      ".vscode-oss/"

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
      "*.fot"
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
}
