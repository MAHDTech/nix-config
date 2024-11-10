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
    # Original bash version.
    "setup-workspaces.sh" = {
      target = "${config.home.homeDirectory}/.local/bin/setup-workspaces.sh";
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

        function log() {
            logger -t "setup-workspaces" "$1"
        }

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

            # We need logger to be installed.
            if ! command -v logger &> /dev/null; then
                echo "logger could not be found"
                return 1
            fi

            return 0
        }

        function setup_workspace() {

            local EVENT=$1
            local WORKSPACE

            case $EVENT in

                # If the event starts with "createworkspace>>"
                "createworkspace>>*")

                    # Start from character 17 to ignore "createworkspace>>"
                    WORKSPACE=$(( ''${EVENT:17:19} ))
                    log "Creating workspace $WORKSPACE"

                    if (( $(("$WORKSPACE" <= "$WORKSPACES_LIMIT")) )); then
                        log "Creating workspace $WORKSPACE on monitor $MONITOR_1"
                        hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_1"
                    else
                        log "Creating workspace $WORKSPACE on monitor $MONITOR_2"
                        hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_2"
                    fi

                    ;;

                # If the event starts with "workspace>>"
                "workspace>>*")

                    # Start from character 11 to ignore "workspace>>"
                    WORKSPACE=$(( ''${EVENT:11:13} ))
                    log "Moving workspace $WORKSPACE v1"

                    if (( $((WORKSPACE <= WORKSPACES_LIMIT)) )); then
                        log "Moving workspace $WORKSPACE to monitor $MONITOR_1"
                        hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_1"
                    else
                        log "Moving workspace $WORKSPACE to monitor $MONITOR_2"
                        hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_2"
                    fi

                    ;;

                # If the event starts with "workspacev2>>"
                "workspacev2>>*")

                    # Start from character 13 to ignore "workspacev2>>"
                    WORKSPACE=$(( ''${EVENT:13:15} ))
                    log "Moving workspace $WORKSPACE v2"

                    if (( $((WORKSPACE <= WORKSPACES_LIMIT)) )); then
                        log "Moving workspace $WORKSPACE to monitor $MONITOR_1"
                        hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_1"
                    else
                        log "Moving workspace $WORKSPACE to monitor $MONITOR_2"
                        hyprctl dispatch moveworkspacetomonitor "$WORKSPACE $MONITOR_2"
                    fi

                    ;;


                # If the event is empty, log and do nothing.
                "")
                    log "Received empty Workspaceevent"
                    return
                    ;;

                # For anything else, log and do nothing.
                *)
                    log "Received unknown Workspace event: $EVENT"
                    return
                    ;;

            esac

            return 0

        }

        # Check if we have the dependencies.
        if ! check_dependencies; then
            exit 1
        else
            log "Dependencies checked successfully"
        fi

        # Wait for edge case of Hyprland not being ready yet.
        sleep 5

        # If the socket exists, start the socket listener.
        SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
        if [[ -S "$SOCKET_PATH" ]]; then
            log "Starting Workspace socket listener"
            socat -U - "UNIX-CONNECT:$SOCKET_PATH" | \
            while read -r LINE; do
                log "Received line: $LINE"
                setup_workspace "$LINE"
            done
        else
            log "A Hyprland Workspace socket does not exist at $SOCKET_PATH"
        fi
      '';
    };

    # Newer Python version.
    "setup-workspaces.py" = {
      target = "${config.home.homeDirectory}/.local/bin/setup-workspaces.py";
      executable = true;

      text = ''
        #!/usr/bin/env python3

        import subprocess
        import os
        import socket

        icons = ["","","","","","","","","",""]

        def setup_workspace(active_workspace):
            icons_index = [0,1,2,3,4]

            icons_index[active_workspace - 1] = icons_index[active_workspace - 1] + 5
            prompt = f"(box (label :text \"{icons[icons_index[0]]}  {icons[icons_index[1]]}  {icons[icons_index[2]]}  {icons[icons_index[3]]}  {icons[icons_index[4]]}\" ))"

            subprocess.run(
                f"echo '{prompt}'",
                shell=True
            )

        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

        server_address = f'{os.environ["XDG_RUNTIME_DIR"]}/hypr/{os.environ["HYPRLAND_INSTANCE_SIGNATURE"]}/.socket2.sock'

        sock.connect(server_address)

        while True:
            new_event = sock.recv(4096).decode("utf-8")
            for item in new_event.split("\n"):
                if "workspace>>" in item:
                    workspaces_num = item[-1]
                    if int(workspaces_num) > 5:
                        workspaces_num = "1"
                        subprocess.run(
                            "hyprctl dispatch workspace 1",
                            shell=True
                        )
                        setup_workspace(int(workspaces_num))
      '';
    };

    # Newest version, replaced with AGS!
  };
}
