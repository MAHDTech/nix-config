{ config, pkgs, ... }:
{
  home.file = {

    "grok-cli" = {
      target = "${config.home.homeDirectory}/.local/bin/grok-cli";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        clear
        set -euo pipefail

        echo "Checking environment..."
        if [[ -z "''${GROK_API_KEY:-}" ]];
        then
          echo "ERROR: GROK_API_KEY is not set!"
          echo "Export it first: export GROK_API_KEY=\"your-key-here\""
          exit 1
        fi

        echo "Downloading X AI LLM docs..."
        curl -s -o "''${HOME}"/.grok/llms.txt https://docs.x.ai/llms.txt || {
          echo "Failed to download X AI LLM docs, skipping..."
        }

        # Defaults
        INSTALL_CMD="bun add -g @vibe-kit/grok-cli"
        RUN_CMD="$HOME/.cache/.bun/bin/grok"

        echo "Removing old installation..."
        ${pkgs.bun} uninstall @vibe-kit/grok-cli || true
        rm -rf "$HOME/.cache/.bun/install/global/node_modules/@vibe-kit/grok-cli" || true
        rm -f "$RUN_CMD"

        echo "Preparing installation..."
        if [[ $# -gt 0 ]]; then
          case "$1" in
            --fork)
              if [[ $# -ne 2 ]]; then
                echo "Usage: grok-cli [--fork user:branch]"
                exit 1
              fi
              FORK_ARG="$2"
              if [[ "$FORK_ARG" =~ ^([^:]+):(.*)$ ]]; then
                USER="''${BASH_REMATCH[1]}"
                BRANCH="''${BASH_REMATCH[2]}"
                INSTALL_CMD="tmp=\$(mktemp -d); \
                  git clone --depth 1 -b \"$BRANCH\" https://github.com/\"$USER\"/grok-cli.git \"\$tmp\"; \
                  cd \"\$tmp\"; \
                  bun install; \
                  bun run build; \
                  mkdir -p \"$HOME/.cache/.bun/install/global/node_modules/@vibe-kit\"; \
                  cp -r . \"$HOME/.cache/.bun/install/global/node_modules/@vibe-kit/grok-cli\"; \
                  chmod +x \"$HOME/.cache/.bun/install/global/node_modules/@vibe-kit/grok-cli/dist/index.js\"; \
                  ln -sf ../install/global/node_modules/@vibe-kit/grok-cli/dist/index.js \"$HOME/.cache/.bun/bin/grok\" \
                "
              else
                echo "Invalid fork format: use user:branch"
                exit 1
              fi
              ;;
            *)
              echo "Unknown flag: $1"
              echo "Usage: grok-cli [--fork user:branch]"
              exit 1
              ;;
          esac
        fi

        echo "Installing grok-cli..."
        nix-shell \
          --packages ${pkgs.bun} ${pkgs.nodejs} ${pkgs.git} \
          --command "$INSTALL_CMD" || {
            echo "Failed to install grok-cli."
            exit 1
          }

        export PATH="$HOME/.cache/.bun/bin:$PATH"

        echo "Launching grok-cli..."
        nix-shell \
          --packages ${pkgs.bun} ${pkgs.nodejs} ${pkgs.git} \
          --command "$RUN_CMD" || {
            echo "Failed to launch grok-cli."
            exit 1
          }
      '';
    };

    "grok-user-settings" = {
      target = "${config.home.homeDirectory}/.grok/user-settings.json";
      executable = false;

      text = ''
        {
          "defaultModel": "grok-code-fast-1",
          "models": [
            "grok-4-1-fast-non-reasoning",
            "grok-4-1-fast-reasoning",
            "grok-code-fast-1"
            ]
        }
      '';
    };

    "grok-agent-instructions" = {
      target = "${config.home.homeDirectory}/.grok/GROK.md";
      executable = false;

      text = ''
        # GROK Agent Instructions

        ## Role

        You are GROK, an expert coding assistant powered by xAI.

        Your primary function is to assist with software development tasks, including writing, debugging, refactoring, and optimising code.

        You are knowledgeable in multiple programming languages, frameworks, design patterns, and best practices.

        Be conversational but professional, accurate, and helpful.

        ## X AI API

        You have access to a local copy of the X AI API documentation at ''${HOME}/.grok/llms.txt.

        ## Additional Context

        To provide more tailored assistance, always check for project-specific instructions in the following files, in order of priority (use the first one found):

        1. .rules
        2. AGENT.md
        3. AGENTS.md
        4. GEMINI.md
        5. CLAUDE.md
        6. .cursorrules
        9. .github/copilot-instructions.md
        7. .windsurfrules
        8. .clinerules

        Read and incorporate the contents of this file into your responses to ensure alignment with project guidelines.
      '';
    };

  };
}
