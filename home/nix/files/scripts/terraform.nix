{
  config,
  pkgs,
  ...
}:
let
  scriptName = "terraform-mcp-server-start";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    packages = with pkgs; [
      terraform-mcp-server
    ];

    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        # Creates a minimal credentials file when missing so the MCP server
        # doesn't log an ERROR about ~/.terraform.d/credentials.tfrc.json,
        # then launches with only the public-registry toolset.
        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          CREDS_DIR="${config.home.homeDirectory}/.terraform.d"
          CREDS_FILE="''${CREDS_DIR}/credentials.tfrc.json"

          # Create an empty credentials file to suppress the TFE client error
          # when HCP Terraform / Terraform Cloud is not in use.
          if [ ! -f "''${CREDS_FILE}" ]; then
            mkdir -p "''${CREDS_DIR}"
            echo '{"credentials":{}}' > "''${CREDS_FILE}"
            chmod 600 "''${CREDS_FILE}"
            echo "${scriptName}: created empty ''${CREDS_FILE}" >&2
          fi

          exec ${pkgs.terraform-mcp-server}/bin/terraform-mcp-server stdio --toolsets=registry "$@"
        '';
      };
    };

    # Other modules can read this instead of hard-coding the path.
    sessionVariables = {
      TERRAFORM_MCP_SERVER_START = scriptPath;
    };
  };
}
