{config, ...}: {
  home.file = {
    "random-wallpaper" = {
      target = "${config.home.homeDirectory}/.local/bin/random-wallpaper";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        #########################
        # Variables
        #########################

        # SWWWW randomize script settings.
        SWWW_SCRIPT="''${0##*/}"
        SWWW_STATE_DIR="''${HOME}/.local/state/swww"
        SWWW_PIDFILE="''${SWWW_STATE_DIR}/pidfile.txt"
        SWWW_LIST_FILE="''${SWWW_STATE_DIR}/wallpapers.txt"

        # SWWW Settings for image transitions.
        export SWWW_TRANSITION_FPS=60
        export SWWW_TRANSITION_STEP=2
        export SWWW_TRANSITION_TYPE="random"

        # This controls (in seconds) when to switch to the next image
        INTERVAL=300

        # Possible values:
        #    -   no:   Do not resize the image
        #    -   crop: Resize the image to fill the whole screen, cropping out parts that don't fit
        #    -   fit:  Resize the image to fit inside the screen, preserving the original aspect ratio
        RESIZE_TYPE="fit"

        #########################
        # Pre-flight checks
        #########################

        if [[ $# -lt 1 ]] || [[ ! -d $1 ]];
        then
          echo "Usage: ''${SWWW_SCRIPT} <dir containing images>"
          exit 1
        elif [[ ! -d "$1" ]];
        then
          echo "Directory does not exist: $1"
          exit 1
        fi
        WALLPAPER_DIR="''${1:-}"

        # Make sure the state directory exists or create it
        mkdir -p "''${SWWW_STATE_DIR}" || {
          echo "Failed to create state directory: ''${SWWW_STATE_DIR}"
          exit 1
        }

        # Make sure only 1 instance of swww_randomize is running
        if [[ -e "''${SWWW_PIDFILE}" ]];
        then
          OLD_PID="$(<"''${SWWW_PIDFILE}")"
          if [[ "''${OLD_PID:-EMPTY}" != "EMPTY" ]] && [[ -e "/proc/''${OLD_PID}" ]];
          then
            OLD_NAME="$(<"/proc/''${OLD_PID}/comm")"
            THIS_NAME="$(<"/proc/''${BASHPID}/comm")"
            if [[ "''${OLD_NAME-OLD_NAME}" == "''${THIS_NAME:-THIS_NAME}" ]];
            then
              echo "The old ''${SWWW_SCRIPT} with PID ''${OLD_PID} is still running"
              exit 1
            else
              echo "Another process with the same ID as the old ''${SWWW_SCRIPT} is running: \"''${OLD_NAME}\"@''${OLD_PID}"
              echo "Replacing the old process ID"
            fi
          fi
        fi
        echo "''${BASHPID}" > "''${SWWW_PIDFILE}"

        #########################
        # Functions
        #########################

        function generate_wallpaper_list() {
          find \
            "''${WALLPAPER_DIR}" \
            -type f \
            -name "*.jpg" \
            -o -name "*.png" \
            -o -name "*.jpeg" \
            -o -name "*.webp" \
            -o -name "*.gif" \
            -o -name "*.bmp" \
            -o -name "*.tiff" \
            | shuf \
            > "''${SWWW_LIST_FILE}"
        }

        #########################
        # Main loop
        #########################

        DISPLAY_LIST=$(swww query | grep -Po "^[^:]+")

        while true;
        do

          # Generate a new list of wallpapers
          generate_wallpaper_list

          # Read the wallpaper list
          exec < "''${SWWW_LIST_FILE}"

          # Set the wallpaper for each display
          for DISPLAY in ''${DISPLAY_LIST};
          do
            read -r IMAGE || break
            echo "Setting image ''${IMAGE} for display: ''${DISPLAY}"
            swww \
              img \
              --resize="''${RESIZE_TYPE}" \
              --outputs "''${DISPLAY}" \
              "''${IMAGE}"
          done

          sleep "''${INTERVAL}"

        done
      '';
    };
  };
}
