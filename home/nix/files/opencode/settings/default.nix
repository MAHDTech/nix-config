{
  config,
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  unstablePkgs = with pkgsUnstable; [
    opencode
    opencode-desktop
  ];
in
{
  # ---------------------------------------------------------------------------
  # OpenCode Configuration
  # ---------------------------------------------------------------------------
  home = {
    file = {
      # OpenCode Settings Template
      "opencode-settings-template" = {
        target = "${config.home.homeDirectory}/.config/opencode/opencode.tmpl.json";
        executable = false;
        text = ''
          {
            "$schema": "https://opencode.ai/config.json",
            "autoupdate": false,
            "plugin" : [
              "opencode-wakatime"
            ],
            "mcp": {
              "devenv": {
                "type": "local",
                "command": [
                  "${pkgsUnstable.devenv}/bin/devenv",
                  "mcp"
                ],
                "environment": {
                }
              },
              "github": {
                "type": "local",
                "command": [
                  "${config.home.homeDirectory}/.local/bin/github-mcp-server-start",
                  "stdio"
                ],
                "environment": { }
              },
              "terraform": {
                "type": "local",
                "command": [
                  "${config.home.homeDirectory}/.local/bin/terraform-mcp-server-start"
                ],
                "environment": { }
              },
              "opentofu": {
                "type": "local",
                "command": [
                  "${config.home.homeDirectory}/.local/bin/opentofu-mcp-server-start"
                ],
                "environment": { }
              },
              "nixos": {
                "type": "local",
                "command": [
                  "${config.home.homeDirectory}/.local/bin/mcp-nixos-start"
                ],
                "environment": { }
              },
              "daisyui": {
                "type": "local",
                "command": [
                  "${config.home.homeDirectory}/.local/bin/daisyui-mcp-server-start"
                ],
                "environment": { }
              }
            },
            "disabled_providers": [
              "github-copilot",
              "github-models",
              "huggingface"
            ],
            "provider": {
              "openrouter": {
                "name": "openrouter",
                "npm": "@openrouter/ai-sdk-provider"
              },
              "ranger": {
                "name": "Ranger",
                "npm": "@ai-sdk/openai-compatible",
                "options": {
                  "baseURL": "http://127.0.0.1:8080/v1",
                  "apiKey": "sk-dummy"
                },
                "models": {
                  "Gemma 4 (8B)": { "name": "Local - Gemma 4 (8B)", "disableTools": false },
                  "Gemma 4 (12B)": { "name": "Local - Gemma 4 (12B)", "disableTools": false }
                }
              }
            }
          }
        '';
      };

      # OpenCode TUI Themes
      "opencode-tui-config" = {
        target = "${config.home.homeDirectory}/.config/opencode/tui.json";
        executable = false;
        text = ''
          {
            "$schema": "https://opencode.ai/tui.json",
            "theme": "tars_synthwave"
          }
        '';
      };
    };

    # ---------------------------------------------------------------------------
    # Activation script: Deep Merge
    # ---------------------------------------------------------------------------
    activation.mergeOpenCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      merge_json() {
        local target="$1"
        local tmpl="$2"
        local tmp_target="$(mktemp)"

        mkdir -p "$(dirname "$target")"

        if [ -f "$target" ] && [ -s "$target" ] && ${pkgs.jq}/bin/jq -e 'if type == "object" then true else false end' "$target" >/dev/null 2>&1; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" "$tmpl" > "$tmp_target"
          mv --force "$tmp_target" "$target"
        else
          cp --force "$tmpl" "$target"
          rm -f "$tmp_target"
        fi
        chmod 600 "$target"
      }

      merge_json "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/opencode.tmpl.json"
    '';

    packages =
      unstablePkgs
      ++ (with pkgs; [
        jq
        github-mcp-server
      ]);
  };
}
