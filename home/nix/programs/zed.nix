{ pkgs, lib, ... }:

{
  programs = {
    zed-editor = {

      enable = true;

      #########################
      # Extensions
      #########################

      extensions = [
        # Languages
        "nix"
        "toml"
        "make"
        "terraform"
        "color-highlight"
        "html"
        "git-firefly"

        # Themes
        "catppuccin-icons"
        "catppuccin"
      ];

      #########################
      # Settings
      #########################

      userSettings = {

        #########################
        # General
        #########################

        auto_update = false;
        hour_format = "hour24";
        shell = "system";
        working_directory = "current_project_directory";
        vim_mode = true;
        load_direnv = "shell_hook";
        base_keymap = "VSCode";
        show_whitespaces = "all";
        ui_font_size = 16;
        buffer_font_size = 16;

        #########################
        # Theme
        #########################

        theme = {
          mode = "system";
          light = "Catppuccin Latte";
          dark = "Catppuccin Mocha";
        };

        #########################
        # Terminal
        #########################

        terminal = {
          alternate_scroll = "off";
          blinking = "off";
          copy_on_select = true;
          dock = "right";
          detect_venv = {
            on = {
              directories = [
                ".env"
                "env"
                ".venv"
                "venv"
              ];
              activate_script = "default";
            };
          };
          activate_script = "default";
        };

        #########################
        # Environment
        #########################

        env = {
          TERM = "cosmic-terminal";
        };

        #########################
        # Fonts
        #########################

        font_family = "VictorMono Nerd Font";
        font_features = null;
        font_size = null;
        line_height = "comfortable";
        option_as_meta = false;
        button = false;

        #########################
        # Toolbar
        #########################

        toolbar = {
          title = true;
        };

        #########################
        # AI Assistant
        #########################
        assistant = {

          enabled = true;
          version = "2";
          default_open_ai_model = null;

          #########################
          # AI Providers
          #########################

          default_model = {
            provider = "openai"; # xAI API key put into OpenAI box.
            model = "grok-code-fast-1";
          };

          inline_alternatives = [
            {
              provider = "openai";
              model = "grok-code-fast-1";
            }
          ];
        };

        #########################
        # Language Server Providers
        #########################

        lsp = {

          rust-analyzer = {
            binary = {
              path = lib.getExe pkgs.rust-analyzer;
              path_lookup = true;
            };
          };

          nix = {
            binary = {
              path = lib.getExe pkgs.nix;
              path_lookup = true;
            };
          };

        };

        #########################
        # Languages
        #########################

        languages = {
        };

      };

    };

  };

}
