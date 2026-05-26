{ config, ... }:
{
  home.file = {
    "antigravity-cli-settings" = {
      target = "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json";
      executable = false;

      text = ''
        {
          "colorScheme": "tokyo night",
          "model": "Gemini 3.5 Flash (High)",
          "notifications": true,
          "permissions": {
            "allow": [
              "command(devenv)",
              "command(nix)"
            ]
          },
          "trustedWorkspaces": [
          ]
        }
      '';
    };

    "antigravity-hub-config" = {
      target = "${config.home.homeDirectory}/.gemini/config/config.json";
      executable = false;

      text = ''
        {
          "userSettings": {
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
}
