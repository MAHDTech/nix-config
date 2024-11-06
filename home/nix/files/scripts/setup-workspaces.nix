{
  config,
  pkgs,
  ...
}: {
  # Ensure dependencies are available
  home.packages = with pkgs; [
    socat
  ];

  home.file = {
    "setup-workspaces" = {
      target = "${config.home.homeDirectory}/.local/bin/setup-workspaces";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        # Primary Monitor
        MONITOR_1="DP-2"

        # Secondary Monitor
        MONITOR_2="DP-3"

        # Max number of workspaces on the primary monitor.
        WORKSPACES_LIMIT=5

        function check_dependencies() {

            # We need hyprctl to be installed.
            if ! command -v hyprctl &> /dev/null; then
                echo "hyprctl could not be found"
                return 1
            fi

            # We need socat to be installed.
            if ! command -v socat &> /dev/null; then
                echo "socat could not be found"
                return 1
            fi

            return 0
        }

        function setup_workspaces() {

            # If we are creating a workspace.
            if [[ "''${1:0:15}" == "createworkspace" ]]; then
                WORKSPACE=$(( ''${1:17:19} ))

                if (( $(("$WORKSPACE" <= "$WORKSPACES_LIMIT")) )); then
                    hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_1"
                else
                    hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_2"
                fi

            # If we are moving a workspace.
            elif [[ ''${1:0:9} == "workspace" ]]; then
                WORKSPACE=$(( ''${1:11:13} ))

                if (( $(($WORKSPACE <= $WORKSPACES_LIMIT)) )); then
                    hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_1"
                else
                    hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_2"
                fi
            fi

        }

        # Check if we have the dependencies.
        if ! check_dependencies; then
            exit 1
        fi

        # Start the socket listener.
        socat - "UNIX-CONNECT:/tmp/hypr/$(echo $HYPRLAND_INSTANCE_SIGNATURE)/.socket2.sock" | \
        while read -r LINE; do
            setup_workspaces "$LINE"
        done
      '';
    };
  };
}
