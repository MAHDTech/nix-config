{
  config,
  pkgs,
  ...
}:
let
  scriptName = "mcp-nixos-start";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    packages = [
      pkgs.mcp-nixos
    ];

    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          exec ${pkgs.mcp-nixos}/bin/mcp-nixos "$@"
        '';
      };
    };

    sessionVariables = {
      MCP_NIXOS_START = scriptPath;
    };
  };
}
