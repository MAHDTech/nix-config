{
  inputs,
  lib,
  pkgs,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
  };

  extraPackagesUnstable = with pkgsUnstable; [
    prettier
  ];

in
{
  xdg = {

    configFile = {
      "zed_keymap" = {
        enable = true;
        force = false;
        executable = false;
        target = "zed/keymap.json";
        text = ''
          [
            {
              "context": "Editor && edit_prediction_conflict",
              "bindings": {
                "alt-l": "editor::AcceptEditPrediction"
              }
            },
            {
              "context": "Workspace",
              "bindings": {
                "ctrl-shift-t": "workspace::NewTerminal"
              }
            },
            {
              "bindings": {
                "ctrl-right": "editor::SelectLargerSyntaxNode",
                "ctrl-left": "editor::SelectSmallerSyntaxNode"
              }
            },
            {
              "context": "ProjectPanel && not_editing",
              "bindings": {
                "o": "project_panel::Open"
              }
            }
          ]
        '';
      };
    };

    desktopEntries = {

      zed = {
        name = "Zed";
        genericName = "Text Editor";
        comment = "A high-performance, multiplayer code editor.";
        exec = "${pkgsUnstable.zed-editor-fhs}/bin/zeditor %U";
        icon = "zed";
        settings = {
          Keywords = "editor;zed";
        };
        categories = [
          "Utility"
          "TextEditor"
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "application/x-zerosize"
          "x-scheme-handler/zed"
        ];

        actions = {
          newWorkspace = {
            name = "Open a new workspace";
            icon = "zed";
            exec = "${pkgsUnstable.zed-editor-fhs}/bin/zeditor --new %U";
          };
        };

      };

    };

  };

  programs = {
    zed-editor = {

      enable = true;
      package = pkgsUnstable.zed-editor-fhs;

      installRemoteServer = false;

      #########################
      # Extensions
      #########################

      extensions = [
        # Languages
        "ansible"
        "astro"
        "basher"
        "caddyfile"
        "crates-lsp"
        "docker-compose"
        "dockerfile"
        "env"
        "git-firefly"
        "github-actions"
        "gitlab-ci-ls"
        "graphviz"
        "html"
        "ini"
        #"jj-lsp" # TODO: jj-lsp in nixpkgs
        "just"
        "make"
        "mermaid"
        "nix"
        "powershell"
        "scss"
        "starlark"
        "tera"
        "terraform"
        "toml"
        "wakatime"

        # Tools
        "codebook"
        "color-highlight"
        "typos"

        # Themes
        "catppuccin"
        "catppuccin-icons"

        # MCP Servers
        "mcp-server-container-use"
        "mcp-server-github"
        "mcp-server-gitlab"
        "terraform-context-server"
      ];

      #########################
      # Extra Packages
      #########################

      extraPackages =
        with pkgs;
        [
          astro-language-server
          clippy
          eslint
          gitlab-ci-ls
          go
          gopls
          golangci-lint
          gotools
          jujutsu
          jq-lsp
          markdownlint-cli2
          nixd
          nil
          nixfmt-rfc-style
          opentofu
          opentofu-ls
          rustc
          rust-analyzer
          shellcheck
          shfmt
          starpls
          terraform
          terraform-ls
          terraform-lsp
          typos
          wakatime-cli
          yamllint
        ]
        ++ extraPackagesUnstable;

      #########################
      # User Settings
      #########################

      userSettings = {

        #########################
        # General
        #########################

        auto_update = false;
        autosave = "on_focus_change";
        disable_ai = false;
        format_on_save = "prettier";
        formatter = "auto";
        #hour_format = "hour12"; # TODO: wtf?
        load_direnv = "shell_hook"; # direct, shell_hook
        show_whitespaces = "all";

        #########################
        # Vim
        #########################

        vim_mode = true;

        vim = {
          default_mode = "normal";
          toggle_relative_line_numbers = false;
          use_system_clipboard = "always";
          use_smartcase_find = true;
          highlight_on_yank_duration = 200;
        };

        #########################
        # User Keymaps
        #########################

        helix_mode = false;

        base_keymap = "VSCode";

        #########################
        # Minimap
        #########################

        minimap = {
          show = "always";
          display_in = "active_editor";
          thumb = "always";
        };

        #########################
        # Search
        #########################

        use_smartcase_search = true;

        #########################
        # Tabs
        #########################

        tabs = {
          git_status = true;
          file_icons = true;
        };

        #########################
        # Features
        #########################

        features = {
          edit_prediction_provider = "zed";
        };

        #########################
        # Prettier Integration
        #########################

        prettier = {
          allowed = true;
          trailingComma = "es5";
          tabWidth = 4;
          semi = false;
          singleQuote = false;
        };

        #########################
        # Diagnostics
        #########################

        diagnostics = {
          button = true;
          include_warnings = true;
          inline = {
            enabled = true;
          };
          cargo = {
            fetch_cargo_diagnostics = false;
          };
        };

        #########################
        # Telemetry
        #########################

        # Anonymised data collection.
        telemetry = {
          diagnostics = true;
          metrics = true;
        };

        #########################
        # Theme
        #########################

        theme = {
          mode = "system";
          light = "Catppuccin Mocha";
          dark = "Catppuccin Mocha";
        };

        icon_theme = "Catppuccin Mocha";

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
          env = {
            TERM = "cosmic-terminal";
          };
          line_height = "comfortable";
          shell = "system";
        };

        #########################
        # Fonts
        #########################

        # Editor Fonts
        buffer_font_family = "VictorMono Nerd Font Mono";
        buffer_font_size = 16;
        buffer_font_weight = 400;
        buffer_line_height = "comfortable";

        # UI Fonts
        ui_font_family = ".SystemUIFont";
        ui_font_size = 16;
        ui_font_weight = 400;

        #########################
        # Layouts
        #########################

        bottom_dock_layout = "contained";

        #########################
        # Image Viewer
        #########################

        image_viewer = {
          unit = "decimal";
        };

        #########################
        # AI Edit Predictions
        #########################

        show_edit_predictions = true;

        edit_predictions = {
          mode = "eager";
        };

        #########################
        # AI Agent
        #########################

        agent = {

          enabled = true;
          preferred_completion_mode = "normal";
          button = true;
          dock = "right";
          always_allow_tool_actions = false;
          stream_edits = false;
          single_file_review = true;
          enable_feedback = true;

          default_profile = "ask";

          notify_when_agent_waiting = "primary_screen";
          play_sound_when_agent_done = true;

          expand_edit_card = true;
          expand_terminal_card = true;

          #########################
          # AI Profiles
          #########################

          profiles = {

            # Writes changes automatically.
            write = {
              name = "Write";
              enable_all_context_servers = true;
              tools = {
                copy_path = true;
                create_directory = true;
                delete_path = true;
                diagnostics = true;
                edit_file = true;
                fetch = true;
                list_directory = true;
                project_notifications = false;
                move_path = true;
                now = true;
                find_path = true;
                read_file = true;
                grep = true;
                terminal = true;
                thinking = true;
                web_search = true;
              };
            };

            # Asks for changes.
            ask = {
              name = "Ask";
              enable_all_context_servers = false;
              tools = {
                contents = true;
                diagnostics = true;
                fetch = true;
                list_directory = true;
                project_notifications = false;
                now = true;
                find_path = true;
                read_file = true;
                open = true;
                grep = true;
                thinking = true;
                web_search = true;
              };
            };

            # Minimal.
            minimal = {
              name = "Minimal";
              enable_all_context_servers = false;
              tools = { };
            };
          };

          #########################
          # AI Providers
          #########################

          default_model = {
            provider = "x_ai";
            model = "grok-code-fast-1";
          };

          inline_assistant_model = {
            provider = "x_ai";
            model = "grok-code-fast-1";
          };

          commit_message_model = {
            provider = "x_ai";
            model = "grok-code-fast-1";
          };

          thread_summary_model = {
            provider = "x_ai";
            model = "grok-code-fast-1";
          };

        };

        #########################
        # AI Language Models
        #########################

        language_models = {
          x_ai = {
            api_url = "https://api.x.ai/v1";
          };
        };

        #########################
        # Language Server Providers
        #########################

        lsp = {
          gitlab-ci = {
            binary = {
              path = lib.getExe pkgs.gitlab-ci-ls;
            };
          };
          rust-analyzer = {
            binary = {
              path = lib.getExe pkgs.rust-analyzer;
            };
            initialization_options = {
              checkOnSave = true;
              check = {
                command = "clippy";
              };
            };
          };
          nixd = {
            binary = {
              path = lib.getExe pkgs.nixd;
            };
          };
          nil = {
            binary = {
              path = lib.getExe pkgs.nil;
            };
          };
        };

        #########################
        # File Types
        #########################

        #file_types = {
        #  "Nix" = [
        #    "nix"
        #  ];
        #};

        #########################
        # Languages
        #########################

        languages = {
          Nix = {
            prettier = {
              allowed = false;
            };
            enable_language_server = true;
            language_servers = [
              "nixd"
              "nil"
            ];
            format_on_save = "on";
            formatter = {
              external = {
                command = "nixfmt";
                arguments = [
                  "--verify"
                ];
              };
            };
          };
        };

      };

    };

  };

  home.file = {
    # The Zed remote server binary.
    ".zed_server" = {
      source = "${pkgs.zed-editor.remote_server}/bin";
      recursive = true;
    };
  };

}
