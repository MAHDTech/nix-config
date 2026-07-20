{
  inputs,
  config,
  pkgs,
  ...
}:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
  };
  scriptName = "opentofu-mcp-server-start";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    packages = [
      pkgsUnstable.opentofu-mcp-server
    ];

    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          exec ${pkgsUnstable.opentofu-mcp-server}/bin/opentofu-mcp-server stdio "$@"
        '';
      };
    };

    sessionVariables = {
      OPENTOFU_MCP_SERVER_START = scriptPath;
    };
  };
}
