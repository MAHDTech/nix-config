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
