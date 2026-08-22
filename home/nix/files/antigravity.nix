{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.file = {

    #########################
    # Antigravity CLI
    #########################

    "antigravity-cli-settings-tmpl" = {
      target = ".gemini/antigravity-cli/settings.tmpl.json";
      executable = false;

      text = ''
        {
          "colorScheme": "tokyo night",
          "editorMode": "vim",
          "enableTerminalSandbox": false,
          "model": "Gemini 3.7 Flash (High)",
          "notifications": true,
          "permissions": {
            "allow": [
              "command(devenv)",
              "command(nix)",
              "mcp(tars/*)"
            ]
          },
          "showFeedbackSurvey": false,
          "toolPermission": "always-proceed"
        }
      '';
    };

    #########################
    # Antigravity Hub
    #########################

    "antigravity-hub-config-tmpl" = {
      target = ".gemini/config/config.tmpl.json";
      executable = false;

      text = ''
        {
          "userSettings": {
            "customThemeSeedsDark": {
              "background": "#24273A",
              "foregroundOverride": "#CAD3F5",
              "primary": "#C6A0F6"
            },
            "customThemeSeedsLight": {
              "background": "#EAECF0",
              "foregroundOverride": "#4C4F69",
              "primary": "#8839EF"
            },
            "globalPermissionGrants": {
              "allow": [
                "mcp(tars/*)"
              ]
            },
            "themeMode": "THEME_MODE_INHERIT",
            "useAiCredits": true
          }
        }
      '';
    };

    #########################
    # Antigravity MCP Servers
    #########################

    "antigravity-mcp-config-tmpl" = {
      target = ".gemini/config/mcp_config.tmpl.json";
      executable = false;

      text = ''
        {
          "mcpServers": {
            "devenv": {
              "serverUrl": "https://mcp.devenv.sh"
            },
            "github": {
              "command": "${config.home.homeDirectory}/.local/bin/github-mcp-server-start",
              "args": [],
              "env": {}
            },
            "terraform": {
              "command": "${config.home.homeDirectory}/.local/bin/terraform-mcp-server-start",
              "args": [],
              "env": {}
            },
            "opentofu": {
              "command": "${config.home.homeDirectory}/.local/bin/opentofu-mcp-server-start",
              "args": [],
              "env": {}
            },
            "nixos": {
              "command": "${config.home.homeDirectory}/.local/bin/mcp-nixos-start",
              "args": [],
              "env": {}
            },
            "daisyui": {
              "command": "${config.home.homeDirectory}/.local/bin/daisyui-mcp-server-start",
              "args": [],
              "env": {}
            }
          }
        }
      '';
    };
  };

  #########################
  # Activation scripts
  #########################

  home.activation = {
    mergeAntigravitySettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

      merge_json "$HOME/.gemini/antigravity-cli/settings.json" "$HOME/.gemini/antigravity-cli/settings.tmpl.json"
      merge_json "$HOME/.gemini/config/config.json" "$HOME/.gemini/config/config.tmpl.json"
      merge_json "$HOME/.gemini/config/mcp_config.json" "$HOME/.gemini/config/mcp_config.tmpl.json"
    '';
  };
}
