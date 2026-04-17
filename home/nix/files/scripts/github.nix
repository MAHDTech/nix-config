{
  config,
  pkgs,
  ...
}:
let
  scriptName = "github-mcp-server-start";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    packages = with pkgs; [
      gh
      github-mcp-server
    ];

    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        # Uses gh CLI to fetch a fresh token on every launch so short-lived
        # tokens never go stale between MCP client restarts.
        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          if ! command -v gh >/dev/null 2>&1; then
            echo "${scriptName}: 'gh' not found on PATH" >&2
            exit 1
          fi

          TOKEN="$(gh auth token 2>/dev/null || true)"
          if [ -z "''${TOKEN}" ]; then
            echo "${scriptName}: no token from 'gh auth token' — run 'gh auth login'." >&2
            exit 1
          else
            echo "${scriptName}: using token from 'gh auth token'"
          fi

          export GITHUB_PERSONAL_ACCESS_TOKEN="''${TOKEN}"
          export GITHUB_TOKEN="''${TOKEN}"

          exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio "$@"
        '';
      };
    };

    # Other modules can read this instead of hard-coding the path.
    sessionVariables = {
      GITHUB_MCP_SERVER_START = scriptPath;
    };
  };
}
