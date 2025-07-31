{ config, ... }:
{
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

        # Wallpaper directory
        WALLPAPER_DIR="''${XDG_WALLPAPERS_DIR:-''${HOME}/Pictures/Wallpapers}"

        # SWWWW randomize script settings.
        SWWW_SCRIPT="''${0##*/}"
        SWWW_STATE_DIR="''${HOME}/.local/state/swww"
        SWWW_PIDFILE="''${SWWW_STATE_DIR}/pidfile.txt"
        SWWW_LIST_FILE="''${SWWW_STATE_DIR}/wallpapers.txt"
        SWWW_LOG_FILE="''${SWWW_STATE_DIR}/random-wallpaper.log"

        # SWWW Settings for image transitions.
        export SWWW_TRANSITION_FPS=60
        export SWWW_TRANSITION_STEP=2
        export SWWW_TRANSITION_TYPE="random"

        # This controls (in seconds) when to switch to the next image
        # 15 minutes
        INTERVAL=900

        # Possible values:
        #    -   no:   Do not resize the image
        #    -   crop: Resize the image to fill the whole screen, cropping out parts that don't fit
        #    -   fit:  Resize the image to fit inside the screen, preserving the original aspect ratio
        RESIZE_TYPE="fit"

        #########################
        # Functions
        #########################

        function msg() {
          CURRENT_TIME=$(date +%Y-%m-%d\ %H:%M:%S)

          echo "''${CURRENT_TIME} - ''${1}" >> "''${SWWW_LOG_FILE}"

          return 0
        }

        function generate_wallpaper_list() {
          msg "Generating wallpaper list"

          find \
            "''${WALLPAPER_DIR}/" \
            -type f \
            -name "*.jpg" \
            -o -name "*.png" \
            -o -name "*.jpeg" \
            -o -name "*.webp" \
            -o -name "*.gif" \
            -o -name "*.bmp" \
            -o -name "*.tiff" \
            | uniq \
            | shuf \
            > "''${SWWW_LIST_FILE}"
        }

        #########################
        # Pre-flight checks
        #########################

        # Start a new log file
        rm -f "''${SWWW_LOG_FILE}" || true

        # Make sure the state directory exists or create it
        mkdir -p "''${SWWW_STATE_DIR}" || {
          notify-send "Random Wallpaper" "Failed to create state directory: ''${SWWW_STATE_DIR}"
          exit 1
        }
        msg "Wallpaper state directory created"

        if [[ ! -d "''${WALLPAPER_DIR}" ]];
        then
          notify-send "Random Wallpaper" "Wallpaper directory does not exist: ''${WALLPAPER_DIR}"
          msg "Wallpaper directory does not exist: ''${WALLPAPER_DIR}"
          exit 1
        fi

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
              msg "The old ''${SWWW_SCRIPT} with PID ''${OLD_PID} is still running"
              exit 1
            else
              msg "Another process with the same ID as the old ''${SWWW_SCRIPT} is running: \"''${OLD_NAME}\"@''${OLD_PID}"
              msg "Replacing the old process ID"
            fi
          fi
        fi
        msg "Recording process ID for swww"
        echo "''${BASHPID}" > "''${SWWW_PIDFILE}"
        msg "swww process ID recorded as ''${BASHPID}"

        #########################
        # Main loop
        #########################

        msg "Querying displays"
        DISPLAY_LIST=$(swww query | grep -Po "^[^:]+")
        msg "Found displays:"
        while IFS= read -r DISPLAY;
        do
          [[ -n "''${DISPLAY}" ]] && msg "  - ''${DISPLAY}"
        done <<< "''${DISPLAY_LIST}"

        while true;
        do

          msg "Starting wallpaper loop"

          # Generate a new list of wallpapers
          generate_wallpaper_list

          msg "Reading wallpaper list"

          # Read the wallpaper list
          exec < "''${SWWW_LIST_FILE}"

          msg "Setting wallpapers"

          # Set the wallpaper for each display
          for DISPLAY in ''${DISPLAY_LIST};
          do
            read -r IMAGE || break
            msg "Setting image ''${IMAGE} for display: ''${DISPLAY}"
            swww \
              img \
              --resize="''${RESIZE_TYPE}" \
              --outputs "''${DISPLAY}" \
              "''${IMAGE}"
          done

          msg "Sleeping for ''${INTERVAL} seconds"

          sleep "''${INTERVAL}"

        done
      '';
    };
  };
}
