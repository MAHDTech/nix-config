{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs; [] ++ unstablePkgs;

  programs.starship = {
    enable = true;

    package = pkgs.starship;

    enableBashIntegration = true;
    enableFishIntegration = false;
    enableIonIntegration = false;
    #enableNushellIntegration = false;
    enableZshIntegration = false;

    settings = {
      # "$schema" = "https://starship.rs/config-schema.json";

      format = lib.concatStrings [
        "$env_var"
        "$battery"
        "$username"
        "$hostname"
        "$shlvl"
        "$directory"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "$hg_branch"
        "$memory_usage"
        "$package"
        "$cmake"
        "$conda"
        "$crystal"
        "$dart"
        "$dotnet"
        "$elixir"
        "$elm"
        "$erlang"
        "$golang"
        "$java"
        "$julia"
        "$nim"
        "$nodejs"
        "$ocaml"
        "$perl"
        "$php"
        "$purescript"
        "$python"
        "$ruby"
        "$rust"
        "$swift"
        "$zig"
        "$nix_shell"
        "$helm"
        "$terraform"
        "$aws"
        "$azure"
        "$gcloud"
        "$docker_context"
        "$kubernetes"
        "$cmd_duration"
        "$custom"
        "$line_break"
        "$jobs"
        "$time"
        "$status"
        "$character"
      ];

      scan_timeout = 100;

      command_timeout = 1000;

      add_newline = true;

      aws = {
        disabled = false;

        displayed_items = "all";
        style = "bold yellow";

        format = "[$symbol$profile(\\($region\\))]($style) ";

        region_aliases = {
          # APAC
          ap-east-1 = "APAC - Hong Kong";
          ap-northeast-1 = "APAC - Tokyo";
          ap-northeast-2 = "APAC - Seoul";
          ap-northeast-3 = "APAC - Osaka";
          ap-south-1 = "APAC - Mumbai";
          ap-southeast-1 = "APAC - Singapore";
          ap-southeast-2 = "APAC - Sydney";

          # AFRICA;
          af-south-1 = "AFRICA - Cape Town";

          # AMER;
          ca-central-1 = "Canada - Central";
          sa-east-1 = "AMER - Sao Paulo";
          us-east-1 = "AMER - Ohio";
          us-east-2 = "AMER - N. Virginia";
          us-gov-east-1 = "AMER - GovCloud - US East";
          us-gov-west-1 = "AMER - GovCloud - US West";
          us-west-1 = "AMER - California";
          us-west-2 = "AMER - Oregon";

          # CHINA;
          cn-north-1 = "CHINA - Beijing";
          cn-northwest-1 = "CHINA - Ningxia";

          # EMEA;
          eu-central-1 = "Europe - Frankfurt";
          eu-south-1 = "Europe - Milan";
          eu-west-1 = "Europe - Ireland";
          eu-west-2 = "Europe - London";
          eu-west-3 = "Europe - Paris";

          # MIDDLE EAST;
          me-south-1 = "ME - Bahrain";
        };
      };

      azure = {
        disabled = false;

        format = "on [$symbol($subscription)]($style) ";

        symbol = "ﴃ ";

        style = "blue bold";
      };

      battery = {
        disabled = false;

        full_symbol = "🔋";
        charging_symbol = "⚡️";
        discharging_symbol = "💀";
        unknown_symbol = "❓";
        empty_symbol = "😞";

        format = "[$symbol$percentage]($style) ";

        display = [
          {
            threshold = 10;
            style = "bold red";
          }

          {
            threshold = 30;
            style = "bold orange";
          }

          {
            threshold = 75;
            style = "bold yellow";
          }

          {
            threshold = 100;
            style = "bold green";
          }
        ];
      };

      character = {
        disabled = false;

        success_symbol = "[❯](bold green)";
        error_symbol = "[X](bold red)";
        vicmd_symbol = "[❮](bold green)";

        format = "$symbol ";
      };

      cmd_duration = {
        disabled = false;

        min_time = 2000;
        show_milliseconds = false;
        style = "bold yellow";

        format = "took [$duration]($style) ";
      };

      directory = {
        disabled = false;

        truncation_length = 5;
        truncation_symbol = ".../";
        truncate_to_repo = true;
        style = "bold cyan";
        read_only = "🔒";
        read_only_style = "red";

        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      docker_context = {
        disabled = false;

        symbol = "🐳 ";
        only_with_files = true;
        style = "bold blue";

        format = "[$symbol$context]($style) ";
      };

      gcloud = {
        disabled = false;

        symbol = "☁️ ";
        style = "bold blue";

        format = "[$symbol$account(\\($region\\))]($style) ";

        region_aliases = {
          asia-east1 = "Changhua County, Taiwan";
          asia-east2 = "Hong Kong";
          asia-northeast1 = "Tokyo, Japan";
          asia-northeast2 = "Osaka, Japan";
          asia-northeast3 = "Seoul, South Korea";
          asia-south1 = "Mumbai, India";
          asia-southeast1 = "Jurong West, Singapore";
          asia-southeast2 = "Jakarta, Indonesia";
          australia-southeast1 = "Sydney, Australia";
          europe-north1 = "Hamina, Finland";
          europe-west1 = "St. Ghislain, Belgium";
          europe-west2 = "London, England, UK";
          europe-west3 = "Frankfurt, Germany";
          europe-west4 = "Eemshaven, Netherlands";
          europe-west6 = "Zürich, Switzerland";
          northamerica-northeast1 = "Montréal, Québec, Canada";
          southamerica-east1 = "Osasco (São Paulo), Brazil";
          us-central1 = "Council Bluffs, Iowa, USA";
          us-east1 = "Moncks Corner, South Carolina, USA";
          us-east4 = "Ashburn, Northern Virginia, USA";
          us-west1 = "The Dalles, Oregon, USA";
          us-west2 = "Los Angeles, California, USA";
          us-west3 = "Salt Lake City, Utah, USA";
          us-west4 = "Las Vegas, Nevada, USA";
        };
      };

      git_branch = {
        disabled = false;

        symbol = " ";
        truncation_length = 25;
        truncation_symbol = "...";
        style = "bold purple";

        format = "on [$symbol$branch]($style) ";
      };

      git_commit = {
        disabled = false;

        commit_hash_length = 7;
        style = "bold green";
        only_detached = true;

        format = "[\\($hash\\)]($style) ";
      };

      git_state = {
        disabled = false;

        rebasing = "REBASING";
        merging = "MERGING";
        reverting = "REVERTING";
        cherry_picking = "🍒 PICKING";
        bisecting = "BISECTING";
        am = "APPLYING-MAILBOX";
        am_or_rebase = "AM/REBASE";
        progress_divider = "/";
        style = "bold yellow";

        format = "[$state]($style) ";
      };

      git_status = {
        disabled = false;

        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        conflicted = "🏳";
        deleted = "🗑";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        modified = "📝";
        renamed = "»";
        staged_style = "green";
        staged_value = "++";
        staged_count.enabled = true;
        staged_count.style = "green";
        stashed = "📦";
        style = "bold red";
        untracked = "🤷‍";

        format = "[$all_status$ahead_behind]($style) ";
      };

      golang = {
        disabled = false;

        symbol = "🐹 ";
        style = "bold cyan";

        format = "[$symbol$version]($style) ";
      };

      helm = {
        disabled = false;

        symbol = "⎈ ";
        style = "bold white";

        format = "[$symbol$version]($style) ";
      };

      hostname = {
        disabled = false;

        ssh_only = true;
        trim_at = ".";
        style = "bold dimmed green";

        format = "[$hostname]($style) in ";
      };

      jobs = {
        disabled = false;

        symbol = "✦";
        threshold = 1;
        style = "bold blue";

        format = "[$symbol$number]($style) ";
      };

      kubernetes = {
        disabled = false;

        symbol = "☸️ ";
        style = "bold blue";
        namespace_spaceholder = "none";

        format = "[$symbol$context( \\($namespace\\))]($style) in ";

        context_aliases = {
          "dev.mahdtech.local" = "Development";
          "stage.mahdtech.local" = "Staging";
          "prod.mahdtech.local" = "Production";
        };
      };

      line_break = {disabled = false;};

      memory_usage = {
        disabled = false;

        threshold = 75;
        symbol = "🐏"; # a RAM, not a Sheep :)
        style = "bold dimmed white";

        format = "$symbol [\${ram}( | \${swap})]($style) ";
      };

      nix-shell = {
        disabled = false;

        symbol = "❄️ ";
        style = "bold blue";

        impure_msg = "[impure shell](bold red)";
        pure_msg = "pure shell](bold green)";

        format = "via [$symbol$state( ($name))]($style) ";
      };

      nodejs = {
        disabled = false;

        symbol = "⬢ ";
        style = "bold green";

        format = "[$symbol$version]($style) ";
      };

      package = {
        disabled = false;

        symbol = "📦 ";
        style = "bold 208";
        display_private = false;

        format = "[$symbol$version]($style) ";
      };

      python = {
        disabled = false;

        symbol = "🐍 ";
        pyenv_version_name = false;
        pyenv_prefix = "pyenv ";
        scan_for_pyfiles = true;
        style = "bold yellow";
        python_binary = "python";

        format = "[$symbol$pyenv_prefix$version( \\($virtualenv\\))]($style) ";
      };

      ruby = {
        disabled = false;

        symbol = "💎 ";
        style = "bold red";

        format = "[$symbol$version]($style) ";
      };

      rust = {
        disabled = false;

        symbol = "🦀 ";
        style = "bold red";

        format = "[$symbol$version]($style) ";
      };

      shlvl = {
        disabled = false;

        threshold = 2;
        symbol = "↕️  ";
        style = "bold yellow";

        format = "[$symbol$shlvl]($style) ";
      };

      singularity = {
        disabled = false;

        symbol = "";
        style = "bold dimmed blue";

        format = "[$symbol\\[$env\\]]($style) ";
      };

      status = {
        disabled = false;

        symbol = "✖";
        style = "bold red";

        format = "[$symbol$status]($style) ";
      };

      terraform = {
        disabled = false;

        symbol = "💠 ";
        style = "bold 105";

        format = "[$symbol$workspace]($style) ";
      };

      time = {
        disabled = false;

        style = "bold yellow";
        time_format = "%T";
        time_range = "-";
        use_12hr = false;
        utc_time_offset = "local";

        format = "🕙 [$time]($style) ";
      };

      username = {
        disabled = false;

        style_root = "bold red";
        style_user = "bold yellow";
        show_always = false;

        format = "[$user]($style) in ";
      };

      env_var = {
        GK_PROFILE = {
          disabled = false;

          variable = "GK_PROFILE";
          symbol = "🔐 ";
          style = "bright-red";

          format = "[$symbol$env_value]($style) ";
        };

        OS_LAYER = {
          disabled = false;

          variable = "OS_LAYER";
          symbol = "🍰 ";
          style = "bold orange";

          format = ''
            [$symbol$env_value]($style)
          '';
        };
      };
    };
  };
}
