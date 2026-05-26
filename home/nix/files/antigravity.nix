{
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
          "enableTerminalSandbox": true,
          "model": "Gemini 3.5 Flash (High)",
          "notifications": true,
          "permissions": {
            "allow": [
              "command(devenv)",
              "command(nix)"
            ]
          }
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
            "themeMode": "THEME_MODE_INHERIT"
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
      # Merge CLI settings
      CLI_TMPL="$HOME/.gemini/antigravity-cli/settings.tmpl.json"
      CLI_TARGET="$HOME/.gemini/antigravity-cli/settings.json"
      CLI_TMP_TARGET="$(mktemp)"

      mkdir -p "$HOME/.gemini/antigravity-cli"

      if [ -f "$CLI_TARGET" ];
      then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$CLI_TARGET" "$CLI_TMPL" > "$CLI_TMP_TARGET"
        mv --force "$CLI_TMP_TARGET" "$CLI_TARGET"
      else
        cp --force "$CLI_TMPL" "$CLI_TARGET"
      fi
      chmod 600 "$CLI_TARGET"

      # Merge Hub config
      HUB_TMPL="$HOME/.gemini/config/config.tmpl.json"
      HUB_TARGET="$HOME/.gemini/config/config.json"
      HUB_TMP_TARGET="$(mktemp)"

      mkdir -p "$HOME/.gemini/config"

      if [ -f "$HUB_TARGET" ];
      then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$HUB_TARGET" "$HUB_TMPL" > "$HUB_TMP_TARGET"
        mv --force "$HUB_TMP_TARGET" "$HUB_TARGET"
      else
        cp --force "$HUB_TMPL" "$HUB_TARGET"
      fi
      chmod 600 "$HUB_TARGET"
    '';
  };
}
