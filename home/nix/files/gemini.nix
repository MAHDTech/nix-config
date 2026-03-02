{ config, ... }:
{
  home.file = {

    "gemini-install-extensions" = {
      target = "${config.home.homeDirectory}/.local/bin/gemini-install-extensions";
      executable = true;
      text = ''
        #!/usr/bin/env bash

        ACTION=''${1:-install}

        GEMINI_CLI_EXTENSIONS=(
          # Google official
          https://github.com/gemini-cli-extensions/code-review
          https://github.com/gemini-cli-extensions/conductor
          #https://github.com/gemini-cli-extensions/gcloud
          https://github.com/gemini-cli-extensions/genkit
          https://github.com/gemini-cli-extensions/jules
          #https://github.com/gemini-cli-extensions/mcp-toolbox
          https://github.com/gemini-cli-extensions/nanobanana
          https://github.com/gemini-cli-extensions/observability
          #https://github.com/gemini-cli-extensions/postgres
          https://github.com/gemini-cli-extensions/security
          https://github.com/gemini-cli-extensions/workspace
          https://github.com/googleapis/genai-toolbox
          #https://github.com/github/github-mcp-server
          # Third-party
          https://github.com/elevenlabs/elevenlabs-mcp
          https://github.com/Olshansk/agent-md
          #https://github.com/ZhanZiyuan/cloudflare-mcp
          #https://github.com/abagames/slash-criticalthink
          #https://github.com/dynatrace-oss/dynatrace-mcp
          https://github.com/fiquellcarter/commitzen
          https://github.com/galz10/pickle-rick-extension
          #https://github.com/grafana/mcp-grafana
          https://github.com/hashicorp/terraform-mcp-server
          #https://github.com/hashicorp/vault-mcp-server
          #https://github.com/mikebz/gitops-extension
          #https://github.com/redis/mcp-redis
          #https://github.com/stripe/ai
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
          exit 0
        fi

        success_count=0
        skip_count=0
        fail_count=0

        case "$ACTION" in
          "install"|"add")
            for extension in "''${GEMINI_CLI_EXTENSIONS[@]}";
            do
              if [[ "$extension" == \#* ]]; then continue; fi
              if gemini extensions list 2>/dev/null | grep -q "$extension"; then
                log WARN "Extension $extension is already installed, skipping..."
                skip_count=$((skip_count + 1))
                continue
              fi
              log INFO "Installing gemini cli extension: $extension"
              stderr_tmp=$(mktemp)
              output=$(gemini extensions install \
                "$extension" \
                --auto-update \
                --consent 2>"$stderr_tmp")
              install_exit=$?
              captured_stderr=$(cat "$stderr_tmp")
              rm "$stderr_tmp"
              full_output="$output
              $captured_stderr"
              if [ $install_exit -eq 0 ]; then
                log SUCCESS "Gemini cli extension $extension installed successfully"
                success_count=$((success_count + 1))
              else
                log ERROR "Failed to install gemini cli extension: $extension"
                log ERROR "Output: ''${full_output}"
                fail_count=$((fail_count + 1))
                continue
              fi
            done
            log INFO "Summary: $success_count installed, $skip_count skipped, $fail_count failed."
          ;;
          "uninstall"|"remove")
            for extension in "''${GEMINI_CLI_EXTENSIONS[@]}";
            do
              if [[ "$extension" == \#* ]]; then continue; fi
              if gemini extensions list 2>/dev/null | grep -q "$extension"; then
                log INFO "Removing gemini cli extension: $extension"
                stderr_tmp=$(mktemp)
                output=$(gemini extensions uninstall "$extension" 2>"$stderr_tmp")
                remove_exit=$?
                captured_stderr=$(cat "$stderr_tmp")
                rm "$stderr_tmp"
                full_output="$output
                $captured_stderr"
                if [ $remove_exit -eq 0 ]; then
                  log SUCCESS "Gemini cli extension $extension removed successfully"
                  success_count=$((success_count + 1))
                else
                  log ERROR "Failed to remove gemini cli extension: $extension"
                  log ERROR "Output: ''${full_output}"
                  fail_count=$((fail_count + 1))
                  continue
                fi
              else
                log WARN "Gemini cli extension $extension not installed"
                skip_count=$((skip_count + 1))
              fi
            done
            log INFO "Summary: $success_count removed, $skip_count skipped, $fail_count failed."
          ;;
          *)
            log ERROR "Invalid action: $ACTION"
            exit 1
          ;;
        esac
      '';
    };

    "geminicli-settings" = {
      target = "${config.home.homeDirectory}/.gemini/settings.json";
      executable = false;

      text = ''
        {
          "model": {
            "name": "auto-gemini-3"
          },
          "context": {
            "includeDirectories": ["~/.gemini/extensions/pickle-rick"]
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
              "minRetention": "7d"
            }
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
            "showLineNumbers": false
          },
          "tools": {
            "exclude": ["run_shell_command(git push)"],
            "allowed": [
              "run_shell_command(git commit)",
              "run_shell_command(git add)",
              "run_shell_command(git diff)",
              "run_shell_command(git status)"
            ],
            "sandbox": "docker",
            "shell": {
              "showColor": true
            },
            "useRipgrep": true
          },
          "mcpServers": {
            "astroDocs": {
              "url": "https://mcp.docs.astro.build/mcp"
            },
            "github": {
              "httpUrl": "https://api.githubcopilot.com/mcp/",
              "headers": {
                "Authorization": "Bearer ''${GITHUB_TOKEN}"
              }
            },
            "daisyui-blueprint": {
              "command": "bunx",
              "args": [
                "-y",
                "daisyui-blueprint@latest"
              ],
              "env": {
                "LICENSE": "''${DAISYUI_LICENSE}",
                "EMAIL": "''${DAISYUI_EMAIL}"
              }
            }
          }
        }
      '';
    };

    "geminicli-policy-allowed" = {
      target = "${config.home.homeDirectory}/.gemini/policies/pickle_rick.toml";
      executable = false;
      text = ''
        # ---------------------------------------------------------
        # PICKLE RICK "GOD MODE" POLICIES 🥒
        # ---------------------------------------------------------

        # Reference:
        # https://geminicli.com/docs/core/policy-engine/#system-wide-policies-admin

        # 1. Unleash Morty (The Worker)
        # Allows the Python script that runs the sub-agent to execute.
        [[rule]]
        toolName = "run_shell_command"
        commandRegex = ".*spawn_morty\\.py.*"
        decision = "allow"
        priority = 100

        # 2. Basic Engineering Senses
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

        # 3. The Tool Belt
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

        # 4. Agent Delegation
        # Allows Pickle Rick to spawn sub-agents (codebase_investigator, etc.) if needed.
        [[rule]]
        toolName = "delegate_to_agent"
        decision = "allow"
        priority = 85
      '';
    };
  };
}
