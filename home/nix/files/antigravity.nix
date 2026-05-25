{ config, ... }:
{
  home.file = {
    "antigravity-settings" = {
      target = "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json";
      executable = false;

      text = ''
        {
          "allowNonWorkspaceAccess": true,
          "altScreenMode": "always",
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
            "/boot/nixos/nix-config",
            "/home/mahdtech/Projects/syncthing/GitHub/tars-cloud",
            "/home/mahdtech/Projects/syncthing/GitHub/tars-cloud/platform",
            "/home/mahdtech/Projects/syncthing/GitHub/tars-cloud/antigravity-plugin"
          ]
        }
      '';
    };
  };
}
