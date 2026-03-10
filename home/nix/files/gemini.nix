{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
  };

  unstablePkgs = with pkgsUnstable; [
    gemini-cli
  ];

in
{
  # ---------------------------------------------------------------------------
  # Gemini CLI
  #
  # ~/.gemini/settings.tmpl.json  — Nix-managed template (read-only)
  # ~/.gemini/settings.json       — writable file owned by the CLI
  #
  # On every `home-manager switch` / `nixos-rebuild switch`, the activation
  # script deep-merges the template INTO the live settings file using jq:
  #
  #   jq -s '.[0] * .[1]' existing.json template.json > settings.json
  #
  # - The template wins for any key it explicitly defines.
  # - Any extra keys written by the CLI are left untouched.
  # ---------------------------------------------------------------------------

  home = {
    file = {

      # -------------------------------------------------------------------------
      # Gemini CLI settings template
      # -------------------------------------------------------------------------
      "geminicli-settings-template" = {
        target = "${config.home.homeDirectory}/.gemini/settings.tmpl.json";
        executable = false;
        text = ''
          {
            "model": {
              "name": "auto-gemini-3"
            },
            "context": {
              "includeDirectories": [
                "~/.gemini/extensions/pickle-rick"
              ]
            },
            "security": {
              "auth": {
                "selectedType": "oauth-personal"
              },
              "folderTrust": {
                "enabled": true
              },
              "environmentVariableRedaction": {
                "enabled": true
              }
            },
            "general": {
              "vimMode": true,
              "sessionRetention": {
                "enabled": true,
                "minRetention": "7d",
                "warningAcknowledged": true,
                "maxAge": "30d"
              },
              "enableAutoUpdate": false
            },
            "hooksConfig": {
              "enabled": true
            },
            "output": {
              "format": "text"
            },
            "ui": {
              "theme": "Default",
              "showMemoryUsage": true,
              "showModelInfoInChat": true,
              "showLineNumbers": false,
              "inlineThinkingMode": "full",
              "showStatusInTitle": true,
              "useAlternateBuffer": true
            },
            "tools": {
              "sandbox": "true",
              "shell": {
                "showColor": true
              },
              "useRipgrep": true
            },
            "mcpServers": {
              "astroDocs": {
                "url": "https://mcp.docs.astro.build/mcp"
              },
              "devenv": {
                "url": "https://mcp.devenv.sh"
              },
              "github": {
                "command": "${pkgs.github-mcp-server}/bin/github-mcp-server",
                "args": ["stdio"],
                "env": {
                  "GITHUB_TOKEN": "$GITHUB_TOKEN"
                }
              },
              "daisyui-blueprint": {
                "command": "${pkgs.bun}/bin/bunx",
                "args": [
                  "-y",
                  "daisyui-blueprint@latest"
                ],
                "env": {
                  "LICENSE": "$DAISYUI_LICENSE",
                  "EMAIL": "$DAISYUI_EMAIL"
                }
              },
              "terraform": {
                "command": "${pkgs.terraform-mcp-server}/bin/terraform-mcp-server",
                "args": ["stdio"],
                "env": {
                  "TFE_TOKEN": "$TFE_TOKEN",
                  "TFE_ADDRESS": "$TFE_ADDRESS",
                  "ENABLE_TF_OPERATIONS": "$ENABLE_TF_OPERATIONS"
                }
              },
              "ElevenLabs": {
                "command": "${pkgs.uv}/bin/uvx",
                "args": ["elevenlabs-mcp"]
              }
            },
            "ide": {
              "enabled": true
            },
            "experimental": {
              "plan": true
            }
          }
        '';
      };

      # -------------------------------------------------------------------------
      # Pickle Rick God Mode policies
      # -------------------------------------------------------------------------
      "geminicli-policy-allowed" = {
        target = "${config.home.homeDirectory}/.gemini/policies/pickle_rick.toml";
        executable = false;
        text = ''
          # ---------------------------------------------------------
          # PICKLE RICK "GOD MODE" POLICIES 🥒
          # ---------------------------------------------------------
          #
          # Reference:
          # https://geminicli.com/docs/core/policy-engine/#system-wide-policies-admin
          #
          # Rules are evaluated highest-priority first.
          # Higher number = evaluated first = wins on conflict.

          # Priority 100 — Unleash Morty (The Worker)
          # Allows the Python script that runs the sub-agent to execute.
          [[rule]]
          toolName = "run_shell_command"
          commandRegex = ".*spawn_morty\\.py.*"
          decision = "allow"
          priority = 100

          # Priority 95 — Basic Engineering Senses
          # Allows Morty to see and touch files without asking "Mother, may I?" every time.
          [[rule]]
          toolName = [
              "activate_skill",
              "create_or_update_file",
              "delete_file",
              "glob",
              "google_web_search",
              "list_directory",
              "read_file",
              "replace",
              "search_file_content",
              "time.getCurrentTime",
              "web_fetch",
              "write_file",
          ]
          decision = "allow"
          priority = 95

          # Priority 91 — Block destructive git operations.
          # Must outrank the broad git allow below (priority 90).
          [[rule]]
          toolName = "run_shell_command"
          commandRegex = "git\\s+push.*"
          decision = "deny"
          priority = 91

          # Priority 90 — The Tool Belt
          # Allows standard dev commands.
          [[rule]]
          toolName = "run_shell_command"
          commandPrefix = [
              "bash",
              "bun",
              "cargo",
              "cp",
              "devenv",
              "git",
              "mkdir",
              "mv",
              "node",
              "npm",
              "op",
              "pre-commit",
              "python3",
              "rm",
              "touch",
          ]
          decision = "allow"
          priority = 90

          # Priority 85 — Agent Delegation
          # Allows Pickle Rick to spawn sub-agents (codebase_investigator, etc.) if needed.
          [[rule]]
          toolName = "delegate_to_agent"
          decision = "allow"
          priority = 85
        '';
      };

      # -------------------------------------------------------------------------
      # Gemini CLI extension manager script
      # -------------------------------------------------------------------------
      "geminicli-extensions" = {
        target = "${config.home.homeDirectory}/.local/bin/gemini-extensions";
        executable = true;
        text = ''
          #!/usr/bin/env bash

          usage() {
            echo "Usage: gemini-extensions <command>"
            echo ""
            echo "Commands:"
            echo "  install    Install all extensions (auto-updates already-installed ones)"
            echo "  uninstall  Uninstall EVERY installed extension (based on ~/.gemini/extensions/* folder names)"
            exit 1
          }

          ACTION=''${1:-}
          [ -z "$ACTION" ] && usage

          # Associative array:
          #  - KEY = extension name (folder)
          #  - VALUE = extension URL:
          declare -A GEMINI_CLI_EXTENSIONS
          GEMINI_CLI_EXTENSIONS=(
            # [agent-md]="https://github.com/Olshansk/agent-md"
            # [cloudflare-mcp]="https://github.com/ZhanZiyuan/cloudflare-mcp"
            # [code-review]="https://github.com/gemini-cli-extensions/code-review"
            # [commitzen]="https://github.com/fiquellcarter/commitzen"
            # [conductor]="https://github.com/gemini-cli-extensions/conductor"
            # [dynatrace-mcp]="https://github.com/dynatrace-oss/dynatrace-mcp"
            # [elevenlabs-mcp]="https://github.com/elevenlabs/elevenlabs-mcp"
            # [gcloud]="https://github.com/gemini-cli-extensions/gcloud"
            # [genai-toolbox]="https://github.com/googleapis/genai-toolbox"
            # [genkit]="https://github.com/gemini-cli-extensions/genkit"
            # [github-mcp-server]="https://github.com/github/github-mcp-server"
            # [gitops-extension]="https://github.com/mikebz/gitops-extension"
            # [jules]="https://github.com/gemini-cli-extensions/jules"
            # [mcp-grafana]="https://github.com/grafana/mcp-grafana"
            # [mcp-redis]="https://github.com/redis/mcp-redis"
            # [mcp-toolbox]="https://github.com/gemini-cli-extensions/mcp-toolbox"
            # [nanobanana]="https://github.com/gemini-cli-extensions/nanobanana"
            # [observability]="https://github.com/gemini-cli-extensions/observability"
            [pickle-rick-extension]="https://github.com/galz10/pickle-rick-extension"
            # [postgres]="https://github.com/gemini-cli-extensions/postgres"
            # [security]="https://github.com/gemini-cli-extensions/security"
            # [slash-criticalthink]="https://github.com/abagames/slash-criticalthink"
            # [stripe-ai]="https://github.com/stripe/ai"
            # [terraform-mcp-server]="https://github.com/hashicorp/terraform-mcp-server"
            # [vault-mcp-server]="https://github.com/hashicorp/vault-mcp-server"
            # [workspace]="https://github.com/gemini-cli-extensions/workspace"
          )

          log() {
            local level=$1
            local message=$2
            local color
            case $level in
              INFO|SUCCESS) color='\033[0;32m' ;;
              WARN) color='\033[0;33m' ;;
              ERROR) color='\033[0;31m' ;;
              *) color='\033[0m' ;;
            esac
            echo -e "''${color}[''${level}] ''${message}\033[0m"
          }

          if ! type gemini > /dev/null 2>&1; then
            log ERROR "gemini cli not found. Please run this from a location where the gemini cli is installed."
            exit 1
          fi

          if ! type jq > /dev/null 2>&1; then
            log ERROR "jq not found. Please ensure jq is installed and available on PATH."
            exit 1
          fi

          if ! type python3 > /dev/null 2>&1; then
            log ERROR "python3 not found. Please ensure python3 is installed and available on PATH."
            exit 1
          fi

          success_count=0
          skip_count=0
          fail_count=0

          case "$ACTION" in
            "install")
              for ext_name in "''${!GEMINI_CLI_EXTENSIONS[@]}"; do
                ext_url="''${GEMINI_CLI_EXTENSIONS[$ext_name]}"
                if [ -d "$HOME/.gemini/extensions/$ext_name" ]; then
                  log INFO "Updating gemini cli extension: $ext_name"
                  stderr_tmp=$(mktemp)
                  output=$(gemini extensions update "$ext_name" 2>"$stderr_tmp")
                  cmd_exit=$?
                  captured_stderr=$(cat "$stderr_tmp")
                  rm "$stderr_tmp"
                  if [ $cmd_exit -eq 0 ]; then
                    log SUCCESS "Gemini cli extension $ext_name updated successfully"
                    success_count=$((success_count + 1))
                  else
                    log ERROR "Failed to update gemini cli extension: $ext_name"
                    log ERROR "Output: $output $captured_stderr"
                    fail_count=$((fail_count + 1))
                  fi
                else
                  log INFO "Installing gemini cli extension: $ext_url"
                  stderr_tmp=$(mktemp)
                  output=$(gemini extensions install \
                    "$ext_url" \
                    --auto-update \
                    --consent 2>"$stderr_tmp")
                  cmd_exit=$?
                  captured_stderr=$(cat "$stderr_tmp")
                  rm "$stderr_tmp"
                  if [ $cmd_exit -eq 0 ]; then
                    log SUCCESS "Gemini cli extension $ext_url installed successfully"
                    success_count=$((success_count + 1))
                  else
                    log ERROR "Failed to install gemini cli extension: $ext_url"
                    log ERROR "Output: $output $captured_stderr"
                    fail_count=$((fail_count + 1))
                  fi
                fi
              done
              log INFO "Summary: $success_count installed/updated, $skip_count skipped, $fail_count failed."
            ;;
            "uninstall")
              EXT_DIR="$HOME/.gemini/extensions"
              if [ ! -d "$EXT_DIR" ]; then
                log INFO "No extensions directory found at $EXT_DIR"
                exit 0
              fi

              found_any=0
              for entry in "$EXT_DIR"/*; do
                [ ! -e "$entry" ] && continue
                [ ! -d "$entry" ] && continue
                ext_name="$(basename "$entry")"
                [ -z "$ext_name" ] && continue
                found_any=1
                log INFO "Removing gemini cli extension: $ext_name"
                stderr_tmp=$(mktemp)
                output=$(gemini extensions uninstall "$ext_name" 2>"$stderr_tmp")
                remove_exit=$?
                captured_stderr=$(cat "$stderr_tmp")
                rm "$stderr_tmp"
                if [ $remove_exit -eq 0 ]; then
                  log SUCCESS "Gemini cli extension $ext_name removed successfully"
                  success_count=$((success_count + 1))
                else
                  log ERROR "Failed to remove gemini cli extension: $ext_name"
                  log ERROR "Output: $output $captured_stderr"
                  fail_count=$((fail_count + 1))
                fi
              done

              if [ $found_any -eq 0 ]; then
                log INFO "No extensions found to uninstall in $EXT_DIR."
                exit 0
              fi

              log INFO "Summary: $success_count removed, $skip_count skipped, $fail_count failed."
            ;;
            *)
              log ERROR "Unknown command: $ACTION"
              usage
            ;;
          esac
        '';
      };

    };

    # ---------------------------------------------------------------------------
    # Activation script
    # ---------------------------------------------------------------------------
    activation.mergeGeminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      TEMPLATE="$HOME/.gemini/settings.tmpl.json"
      TARGET="$HOME/.gemini/settings.json"
      TMP_TARGET="$(mktemp)"

      if [ -f "$TARGET" ]; then
        # Deep-merge: existing keys are base, template keys win for overlapping paths.
        # This enforces your declarative defaults while preserving CLI-managed keys
        # (e.g. auth tokens, cached state inside nested objects).
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$TARGET" "$TEMPLATE" > "$TMP_TARGET"
        mv "$TMP_TARGET" "$TARGET"
      else
        cp "$TEMPLATE" "$TARGET"
      fi

      chmod 600 "$TARGET"
    '';

    packages =
      with pkgs;
      [
        bun # daisyui-blueprint MCP
        github-mcp-server # github MCP
        jq # JSON parser
        nodejs # gemini-cli-security extension
        terraform-mcp-server # terraform MCP
        uv # elevenlabs-mcp
      ]
      ++ unstablePkgs;
  };
}
