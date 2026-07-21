{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
  };

  extraPackagesUnstable = with pkgsUnstable; [
    # Tools
    prettier
    jq
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
        source = ./keymap.json;
      };
    };

    desktopEntries = {

      zed = {
        name = "Zed";
        genericName = "Text Editor";
        comment = "A high-performance, multiplayer code editor.";
        exec = "${pkgsUnstable.zed-editor}/bin/zed %U";
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
            exec = "${pkgsUnstable.zed-editor}/bin/zed --new %U";
          };
        };

      };

    };

  };

  programs = {
    zed-editor = {

      enable = true;
      package = pkgsUnstable.zed-editor;

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
        "cargo-appraiser"
        "crates-lsp"
        "docker-compose"
        "dockerfile"
        "env"
        "git-firefly"
        "github-actions"
        "gitlab-ci-ls"
        "golangci-lint"
        "graphviz"
        "html"
        "ini"
        #"jj-lsp" # TODO: jj-lsp in nixpkgs
        "jinja2"
        "just"
        "make"
        "mermaid"
        "nix"
        "powershell"
        "scss"
        "starlark"
        "svelte"
        "tera"
        "terraform"
        "toml"
        "wakatime"

        # Tools
        "color-highlight"
        "cspell"

        # Themes
        "catppuccin"
        "catppuccin-icons"

        # MCP Servers
        "mcp-server-container-use"
        "mcp-server-github"
        "mcp-server-gitlab"
        "mcp-nixos"
        "terraform-mcp-server"
      ];

      #########################
      # Extra Packages
      #########################

      extraPackages =
        with pkgs;
        [
          # Shared Libraries
          cacert
          openssl
          zlib

          # Language Servers
          astro-language-server
          bash-language-server
          dockerfile-language-server
          gitlab-ci-ls
          gopls
          jq-lsp
          nixd
          nil
          typescript-language-server
          powershell-editor-services
          rust-analyzer
          starpls
          terraform-ls
          terraform-lsp
          tofu-ls
          vscode-langservers-extracted

          # Linters
          clippy
          cspell
          eslint
          golangci-lint
          markdownlint-cli2
          shellcheck
          tflint
          yamllint

          # Package Managers
          cargo
          bun

          # Formatters
          nixfmt
          rustfmt
          shfmt

          # Programming Languages
          go
          nodejs
          powershell
          rustc
          typescript

          # Infrastructure Tools
          devenv
          opentofu
          pulumi
          pulumiPackages.pulumi-go
          terraform

          # Version Control
          git
          jujutsu

          # Containers
          docker-client
          docker-compose

          # Debugging
          delve

          # Utilities
          gotools
          uv
          wakatime-cli
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
        format_on_save = "on";
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
        # Terminal
        #########################

        terminal = {
          font_size = 18;
          #font_family = "" # Defaults to Editor font.
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
            TERM = "ghostty";
          };
          line_height = "comfortable";
          shell = "system";
        };

        #########################
        # Fonts
        #
        # To get fallback order;
        # fc-match "FontName" -s
        #########################

        # Editor Fonts
        buffer_font_family = "JetBrainsMono Nerd Font";
        buffer_font_fallbacks = [
          "Noto Color Emoji"
          ".ZedMono"
        ];
        buffer_font_features = {
          calt = true; # Enable/Disable Ligatures
        };
        buffer_line_height = "comfortable";
        buffer_font_size = 20;
        buffer_font_weight = 500;

        # UI Fonts
        ui_font_family = "Clarity City";
        ui_font_fallbacks = [
          "Noto Color Emoji"
          ".SystemUIFont"
          ".ZedSans"
        ];
        ui_font_size = 20;
        ui_font_weight = 500;

        # Agent Fonts
        agent_ui_font_size = 20;

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
          provider = "zed";
        };

        #########################
        # AI Agent Servers
        #########################

        agent_servers = {
          "antigravity" = {
            type = "registry";
          };
          "claude-acp" = {
            type = "registry";
          };
          "goose" = {
            type = "registry";
          };
          "opencode" = {
            type = "registry";
          };
        };

        #########################
        # AI Agent
        #########################

        agent = {

          enabled = true;
          button = true;
          dock = "right";
          single_file_review = true;
          enable_feedback = true;

          default_profile = "ask";

          notify_when_agent_waiting = "primary_screen";
          play_sound_when_agent_done = true;

          expand_edit_card = true;
          expand_terminal_card = true;

          tool_permissions = {
            default = "confirm";
            tools = {
              terminal = {
                default = "confirm";
              };
              edit_file = {
                default = "confirm";
              };
              delete_path = {
                default = "confirm";
              };
              move_path = {
                default = "confirm";
              };
              copy_path = {
                default = "allow";
              };
              create_directory = {
                default = "allow";
              };
              restore_file_from_disk = {
                default = "allow";
              };
              save_file = {
                default = "allow";
              };
              fetch = {
                default = "allow";
              };
              web_search = {
                default = "allow";
              };
            };
          };

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
                find_path = true;
                grep = true;
                list_directory = true;
                move_path = true;
                now = true;
                open = true;
                project_notifications = true;
                read_file = true;
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
                find_path = true;
                grep = true;
                list_directory = true;
                now = true;
                open = true;
                project_notifications = false;
                read_file = true;
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
          open_router = {
            available_models = [
              {
                name = "openrouter/auto";
                display_name = "OpenRouter Auto";
                context_window = 100000;
                max_tokens = 100000;
                supports_tools = true;
                supports_images = true;
              }
            ];
          };
          openai_compatible = {
            "Ranger" = {
              api_url = "http://127.0.0.1:8080/v1";
              available_models = [
                {
                  name = "Gemma 4 (8B)";
                  display_name = "Ranger - Gemma 4 (8B)";
                  context_window = 100000;
                  max_tokens = 100000;
                  capabilities = {
                    chat_completions = true;
                    images = false;
                    parallel_tool_calls = false;
                    prompt_cache_key = false;
                    tools = true;
                  };
                }
              ];
            };
          };
        };

        #########################
        # AI Context Servers
        #########################

        context_servers = {
          svelte = {
            command = "bunx";
            args = [
              "-y"
              "@sveltejs/mcp"
            ];
          };
          astroDocs = {
            url = "https://mcp.docs.astro.build/mcp";
          };

          avalanche = {
            url = "https://build.avax.network/api/mcp";
          };

          daisyui = {
            # Use a wrapper that injects the DaisyUI license.
            command = "${config.home.homeDirectory}/.local/bin/daisyui-mcp-server-start";
            args = [ ];
            env = { };
          };

          devenv = {
            command = "devenv";
            args = [ "mcp" ];
            env = { };
          };

          nixos = {
            command = "${config.home.homeDirectory}/.local/bin/mcp-nixos-start";
            args = [ ];
            env = { };
          };

          github = {
            # Use a wrapper that injects the GITHUB_TOKEN using gh CLI
            command = "${config.home.homeDirectory}/.local/bin/github-mcp-server-start";
            args = [ ];
            env = { };
          };

          terraform = {
            # Use a wrapper that creates credentials and runs registry-only mode
            command = "${config.home.homeDirectory}/.local/bin/terraform-mcp-server-start";
            args = [ ];
            env = { };
          };

          opentofu = {
            # Use a wrapper that runs registry-only mode
            command = "${config.home.homeDirectory}/.local/bin/opentofu-mcp-server-start";
            args = [ ];
            env = { };
          };

        };

        #########################
        # Language Server Providers
        #########################

        lsp = {
          devenv-lsp = {
            binary = {
              path = lib.getExe pkgs.devenv;
              args = [
                "lsp"
              ];
            };
          };
          gitlab-ci = {
            binary = {
              path = lib.getExe pkgs.gitlab-ci-ls;
            };
          };
          gopls = {
            initialization_options = {
              hints = {
                assignVariableTypes = true;
                compositeLiteralFields = true;
                compositeLiteralTypes = true;
                constantValues = true;
                functionTypeParameters = true;
                parameterNames = true;
                rangeVariableTypes = true;
              };
            };
          };
          rust-analyzer = {
            enable_lsp_tasks = true;
            initialization_options = {
              diagnostics = {
                experimental = {
                  enable = true;
                };
              };
              # https://rust-analyzer.github.io/book/features.html#inlay-hints
              inlayHints = {
                maxLength = null;
                lifetimeElisionHints = {
                  enable = "skip_trivial";
                  useParameterNames = true;
                };
                closureReturnTypeHints = {
                  enable = "always";
                };
              };
              checkOnSave = true;
              check = {
                workspace = true;
              };
              cargo = {
                allTargets = true;
                noDefaultFeatures = false;
                sysroot = null; # Auto-detects from PATH
              };
              rust = {
                analyzerTargetDir = true;
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
          powershell-es = {
            binary = {
              path = lib.getExe pkgs.powershell-editor-services;
            };
          };
          tailwindcss-language-server = {
            settings = {
              classFunctions = [
                "cva"
                "cx"
              ];
              experimental = {
                classRegex = [
                  "[cls|className]\\s\\:\\=\\s\"([^\"]*)"
                ];
              };
            };
          };
          terraform-ls = {
            initialization_options = {
              experimentalFeatures = {
                prefillRequiredFields = true;
              };
            };
          };
          yaml-language-server = {
            settings = {
              yaml = {
                keyOrdering = false; # Enable to warn on alphabetical ordering.
                format = {
                  singleQuote = true;
                };
                schemas = {
                  "https://raw.githubusercontent.com/ansible/ansible-lint/main/src/ansiblelint/schemas/inventory.json" =
                    [
                      "./inventory/*.yaml"
                      "hosts.yml"
                    ];
                };
              };
            };
          };
        };

        #########################
        # File Types
        #########################

        file_types = {
          "Dockerfile" = [
            "**/Dockerfile"
            "**/Dockerfile*"
            "**/Dockerfile.*"
          ];
          "Ansible" = [
            "**.ansible.yml"
            "**.ansible.yaml"
            "**/defaults/*.yml"
            "**/defaults/*.yaml"
            "**/meta/*.yml"
            "**/meta/*.yaml"
            "**/tasks/*.yml"
            "**/tasks/*.yaml"
            "**/handlers/*.yml"
            "**/handlers/*.yaml"
            "**/group_vars/*.yml"
            "**/group_vars/*.yaml"
            "**/host_vars/*.yml"
            "**/host_vars/*.yaml"
            "**/playbooks/*.yml"
            "**/playbooks/*.yaml"
            "**playbook*.yml"
            "**playbook*.yaml"
          ];
          "dotenv" = [ ".env*" ];
          "Helm" = [
            "**/templates/**/*.tpl"
            "**/templates/**/*.yaml"
            "**/templates/**/*.yml"
            "**/helmfile.d/**/*.yaml"
            "**/helmfile.d/**/*.yml"
            "**/values*.yaml"
          ];
          "Markdown" = [ "*.mdx" ];
        };

        #########################
        # Languages
        #########################

        languages = {
          "Markdown" = {
            format_on_save = "on";
            remove_trailing_whitespace_on_save = true;
            hard_tabs = false;
          };
          "Rust" = {
            prettier = {
              allowed = false;
            };
          };
          "Nix" = {
            prettier = {
              allowed = false;
            };
            enable_language_server = true;
            language_servers = [
              "devenv-lsp"
              "nixd"
              "nil"
            ];
            format_on_save = "on";
            formatter = {
              external = {
                command = lib.getExe pkgs.nixfmt;
                arguments = [
                  "--verify"
                ];
              };
            };
          };
          "Shell Script" = {
            tab_size = 4;
            hard_tabs = true;
            format_on_save = "on";
            formatter = {
              external = {
                command = "shfmt";
                arguments = [
                  "--filename"
                  "{buffer_path}"
                  "--indent"
                  "0"
                ];
              };
            };
          };
          "Terraform" = {
            prettier = {
              allowed = false;
            };
            enable_language_server = true;
            language_servers = [
              "terraform-ls"
              "terraform-lsp"
            ];
            format_on_save = "on";
            formatter = {
              external = {
                command = lib.getExe pkgs.terraform;
                arguments = [
                  "fmt"
                  "-write=true"
                  "-"
                ];
              };
            };
          };
          "TypeScript" = {
            language_servers = [
              "!typescript-language-server"
              "vtsls"
              "..."
            ];
          };
          "TSX" = {
            language_servers = [
              "!typescript-language-server"
              "vtsls"
              "..."
            ];
          };
          "JavaScript" = {
            language_servers = [
              "!typescript-language-server"
              "vtsls"
              "..."
            ];
          };
          "YAML" = {
            tab_size = 2;
            format_on_save = "on";
            formatter = "auto";
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
