{
  config,
  pkgs,
  ...
}:
let
  scriptName = "daisyui-mcp-server-start";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    packages = with pkgs; [
      bun
    ];

    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        # Uses gh CLI to fetch a fresh token on every launch so short-lived
        # tokens never go stale between MCP client restarts.
        text = ''
          #!/usr/bin/env bash
          set -a
          export EMAIL="$(cat ${config.home.homeDirectory}/.config/daisyui/email)"
          export LICENSE="$(cat ${config.home.homeDirectory}/.config/daisyui/license)"
          set +a
          exec bunx daisyui-blueprint@latest -y "$@"
        '';
      };
    };

    # Other modules can read this instead of hard-coding the path.
    sessionVariables = {
      DAISYUI_MCP_SERVER_START = scriptPath;
    };
  };
}
