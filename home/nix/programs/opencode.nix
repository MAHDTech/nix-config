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
                  "gemma-2-9b-it": { "name": "gemma-2-9b-it", "disableTools": true },
                  "Mistral-7B-Instruct-v0.3": { "name": "Mistral-7B-Instruct-v0.3", "disableTools": true },
                  "Meta-Llama-3.1-8B-Instruct": { "name": "Meta-Llama-3.1-8B-Instruct", "disableTools": true },
                  "OmniCoder-9B": { "name": "OmniCoder-9B", "disableTools": true },
                  "Qwen2.5-Coder-14B-Instruct": { "name": "Qwen2.5-Coder-14B-Instruct", "disableTools": true },
                  "Qwen2.5-Coder-7B-Instruct": { "name": "Qwen2.5-Coder-7B-Instruct", "disableTools": true },
                  "Qwen2.5-Coder-3B-Instruct": { "name": "Qwen2.5-Coder-3B-Instruct", "disableTools": true },
                  "codegeex4-all-9b": { "name": "codegeex4-all-9b", "disableTools": true },
                  "Phi-3-mini-4k-instruct": { "name": "Phi-3-mini-4k-instruct", "disableTools": true },
                  "Qwen2-Math-7B-Instruct": { "name": "Qwen2-Math-7B-Instruct", "disableTools": true }
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
            "theme": "tokyonight"
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
