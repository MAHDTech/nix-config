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
                  "${pkgs.github-mcp-server}/bin/github-mcp-server",
                  "stdio"
                ],
                "environment": {
                  "GITHUB_TOKEN": "$GITHUB_TOKEN"
                }
              }
            },
            "provider": {
              "gemini": {
                "name": "gemini",
                "npm": "@ai-sdk/google"
              },
              "local": {
                "name": "local",
                "npm": "@ai-sdk/openai-compatible",
                "options": {
                  "baseURL": "http://127.0.0.1:8080/v1",
                  "apiKey": "sk-dummy"
                },
                "models": {
                  "Llama 3 (8B Instruct)": { "name": "Local - Llama 3 8B", "disableTools": true },
                  "Llama 3.1 (8B Instruct)": { "name": "Local - Llama 3.1 8B", "disableTools": true },
                  "Llama 3.2 (1B Instruct)": { "name": "Local - Llama 3.2 1B", "disableTools": true },
                  "Llama 3.2 (3B Instruct)": { "name": "Local - Llama 3.2 3B", "disableTools": true },
                  "Llama 3.2 (1BQ4 Instruct)": { "name": "Local - Llama 3.2 1B (Q4)", "disableTools": true },
                  "TinyLlama": { "name": "Local - TinyLlama", "disableTools": true },
                  "Parrot": { "name": "Local - Mamba Parrot", "disableTools": true }
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
