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
    opencode
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
      TEMPLATE="$HOME/.config/opencode/opencode.tmpl.json"
      TARGET="$HOME/.config/opencode/opencode.json"
      TMP_TARGET="$(mktemp)"

      mkdir -p "$HOME/.config/opencode"

      if [ -f "$TARGET" ]; then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$TARGET" "$TEMPLATE" > "$TMP_TARGET"
        mv --force "$TMP_TARGET" "$TARGET"
      else
        cp --force "$TEMPLATE" "$TARGET"
      fi

      chmod 600 "$TARGET"
    '';

    packages =
      unstablePkgs
      ++ (with pkgs; [
        jq
        github-mcp-server
      ]);
  };
}
