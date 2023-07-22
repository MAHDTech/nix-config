{
  inputs,
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

    package = pkgsUnstable.starship;

    enableBashIntegration = true;
    enableFishIntegration = false;
    enableIonIntegration = false;
    #enableNushellIntegration = false;
    enableZshIntegration = false;

    settings = {
      # "$schema" = "https://starship.rs/config-schema.json";

      format = lib.concatStrings [
        "$env_var"
        "$username"
        "$hostname"
        "$localip"
        "$shlvl"
        "$singularity"
        "$kubernetes"
        "$directory"
        "$vcsh"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_metrics"
        "$git_status"
        "$hg_branch"
        "$docker_context"
        "$package"
        "$c"
        "$cmake"
        "$cobol"
        "$daml"
        "$dart"
        "$deno"
        "$dotnet"
        "$elixir"
        "$elm"
        "$erlang"
        "$golang"
        "$guix_shell"
        "$haskell"
        "$haxe"
        "$helm"
        "$java"
        "$julia"
        "$kotlin"
        "$lua"
        "$nim"
        "$nodejs"
        "$ocaml"
        "$opa"
        "$perl"
        "$php"
        "$pulumi"
        "$purescript"
        "$python"
        "$raku"
        "$rlang"
        "$red"
        "$ruby"
        "$rust"
        "$scala"
        "$swift"
        "$terraform"
        "$vlang"
        "$vagrant"
        "$zig"
        "$buf"
        "$nix_shell"
        "$conda"
        "$meson"
        "$spack"
        "$memory_usage"
        "$aws"
        "$gcloud"
        "$openstack"
        "$azure"
        "$crystal"
        "$custom"
        "$sudo"
        "$cmd_duration"
        "$line_break"
        "$jobs"
        "$battery"
        "$time"
        "$status"
        "$os"
        "$container"
        "$shell"
        "$character"
      ];

      scan_timeout = 100;

      command_timeout = 1000;

      add_newline = true;

      aws = {
        disabled = false;

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
      };

      battery = {
        disabled = false;

        full_symbol = "🔋";
        charging_symbol = "⚡";
        discharging_symbol = "🪫";
        unknown_symbol = "❓";
        empty_symbol = "💀";

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
      };

      cmake = {
        disabled = false;
      };

      cmd_duration = {
        disabled = false;

        min_time = 2000;
        show_milliseconds = false;
      };

      container = {
        disabled = false;
      };

      directory = {
        disabled = false;
      };

      docker_context = {
        disabled = false;
      };

      gcloud = {
        disabled = false;

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
      };

      git_commit = {
        disabled = false;
      };

      git_state = {
        disabled = false;
      };

      git_metrics = {
        disabled = false;
      };

      git_status = {
        disabled = false;
      };

      golang = {
        disabled = false;
      };

      helm = {
        disabled = false;
      };

      hostname = {
        disabled = false;
      };

      jobs = {
        disabled = false;
      };

      kubernetes = {
        disabled = false;

        context_aliases = {
          "dev.mahdtech.local" = "Development";
          "stage.mahdtech.local" = "Staging";
          "prod.mahdtech.local" = "Production";
        };

        user_aliases = {
          "dev.mahdtech.local" = "development";
          "stage.mahdtech.local" = "staging";
          "prod.mahdtech.local" = "production";
        };
      };

      line_break = {disabled = false;};

      memory_usage = {
        disabled = false;
        symbol = "🐏"; # a RAM, not a Sheep :)
      };

      nix_shell = {
        disabled = false;
      };

      nodejs = {
        disabled = false;
      };

      os = {
        disabled = false;

        symbols = {
          Alpine = " ";
          Amazon = " ";
          Android = " ";
          Arch = " ";
          CentOS = " ";
          Debian = " ";
          DragonFly = " ";
          Emscripten = " ";
          EndeavourOS = " ";
          Fedora = " ";
          FreeBSD = " ";
          Garuda = "﯑ ";
          Gentoo = " ";
          HardenedBSD = "ﲊ ";
          Illumos = " ";
          Linux = " ";
          Macos = " ";
          Manjaro = " ";
          Mariner = " ";
          MidnightBSD = " ";
          Mint = " ";
          NetBSD = " ";
          NixOS = " ";
          OpenBSD = " ";
          OracleLinux = " ";
          Pop = " ";
          Raspbian = " ";
          RedHatEnterprise = " ";
          Redhat = " ";
          Redox = " ";
          SUSE = " ";
          Solus = "ﴱ ";
          Ubuntu = " ";
          Unknown = " ";
          Windows = " ";
          openSUSE = " ";
        };
      };

      package = {
        disabled = false;
      };

      pulumi = {
        disabled = false;
      };

      python = {
        disabled = false;
      };

      ruby = {
        disabled = false;
      };

      rust = {
        disabled = false;
      };

      shlvl = {
        disabled = false;
      };

      singularity = {
        disabled = false;
      };

      status = {
        disabled = false;
      };

      sudo = {
        disabled = false;
      };

      terraform = {
        disabled = false;
      };

      time = {
        disabled = false;
        format = "🕙 [$time]($style) ";
      };

      username = {
        disabled = false;
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
