{ config, pkgs, ... }:
{
  home = {

    packages = [
      pkgs.swww
      pkgs.findutils
    ];

    file = {
      "wallpaper-manager-daemon" = {
        target = "${config.home.homeDirectory}/.local/bin/wallpaper-manager-daemon";
        executable = true;

        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          ##################################################
          # Wallpaper Manager Daemon Script
          #
          # This script starts swww-daemon in the foreground.
          #
          # It's designed to be run as a systemd service.
          ##################################################

          ##################################################
          # Functions
          ##################################################

          function log() {
            local PRIORITY="$1"
            local MESSAGE="$2"
            local TAG="wallpaper-manager-daemon"

            # Ensure the priority is valid for logger.
            case "$PRIORITY" in
              "info" | "information") # Informational messages.
                LEVEL="info"
                ;;
              "error" | "critical" | "err" | "crit") # Error messages.
                LEVEL="err"
                ;;
              "warning" | "warn") # Warning messages.
                LEVEL="warning"
                ;;
              *) # Unknown messages.
                LEVEL="info"
                PRIORITY="info"
                ;;
            esac

            logger -t "''${TAG:-wallpaper-manager-daemon}" -p "''${LEVEL:-info}" "''${MESSAGE}"

            return 0
          }

          function cleanup() {
            log "info" "Received signal, cleaning up wallpaper manager daemon..."

            # Kill all swww-daemon processes
            pkill -f "swww-daemon" || {
              log "error" "Failed to kill swww-daemon processes"
              exit 1
            }

            exit 0
          }

          ##################################################
          # Main
          ##################################################

          log "info" "Starting wallpaper manager daemon service"

          # Set up signal handlers for graceful cleanup
          trap cleanup INT TERM EXIT

          # Try to detect Wayland display dynamically
          if [[ "''${WAYLAND_DISPLAY:-EMPTY}" == "EMPTY" ]];
          then
            # Look for active Wayland displays
            NUM_ATTEMPTS=10
            i=1
            while [[ $i -le ''${NUM_ATTEMPTS} ]];
            do
              log "info" "Checking for wayland-''${i} socket (attempt $i/''${NUM_ATTEMPTS})"
              if [[ -S "''${XDG_RUNTIME_DIR}/wayland-''${i}" ]];
              then
                export WAYLAND_DISPLAY="wayland-''${i}"
                log "info" "Auto-detected WAYLAND_DISPLAY=wayland-''${i}"
                break
              fi
              i=$((i + 1))
            done
          fi

          # Set additional Wayland environment variables
          if [[ "''${WAYLAND_DISPLAY:-EMPTY}" != "EMPTY" ]];
          then
            # Set swww socket path
            export SWWW_SOCKET="''${XDG_RUNTIME_DIR}/swww-''${WAYLAND_DISPLAY}.socket"
            log "info" "Set SWWW_SOCKET=''${SWWW_SOCKET}"

            # Try to detect Hyprland instance signature
            NUM_ATTEMPTS=10
            i=1
            while [[ $i -le ''${NUM_ATTEMPTS} ]];
            do
              log "info" "Checking for hyprland-instance-''${i} socket (attempt $i/''${NUM_ATTEMPTS})"
              if [[ -S "''${XDG_RUNTIME_DIR}/hyprland-instance-''${i}" ]];
              then
                export HYPRLAND_INSTANCE_SIGNATURE="''${XDG_RUNTIME_DIR}/hyprland-instance-''${i}"
                log "info" "Auto-detected HYPRLAND_INSTANCE_SIGNATURE=''${HYPRLAND_INSTANCE_SIGNATURE}"
                break
              fi
              i=$((i + 1))
            done
          fi

          log "info" "Environment: WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-unset}, XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-unset}"
          log "info" "Environment: SWWW_SOCKET=''${SWWW_SOCKET:-unset}, HYPRLAND_INSTANCE_SIGNATURE=''${HYPRLAND_INSTANCE_SIGNATURE:-unset}"

          # Start swww-daemon in foreground
          log "info" "Starting swww-daemon..."
          exec ${pkgs.swww}/bin/swww-daemon --no-cache
        '';
      };

      "wallpaper-manager" = {
        target = "${config.home.homeDirectory}/.local/bin/wallpaper-manager";
        executable = true;

        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          ##################################################
          # Wallpaper Manager Script
          #
          # This script manages wallpaper rotation.
          # It waits for swww-daemon to be ready before starting.
          #
          # It's designed to be run as a systemd service.
          ##################################################

          ##################################################
          # Variables
          ##################################################

          # Wallpaper directory
          WALLPAPER_DIR="''${XDG_WALLPAPERS_DIR:-''${HOME}/Pictures/Wallpapers}"

          # SWWW settings
          SWWW_STATE_DIR="${config.home.homeDirectory}/.local/state/swww"
          SWWW_LIST_FILE="''${SWWW_STATE_DIR}/wallpapers.txt"

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

          ##################################################
          # Functions
          ##################################################

          function log() {
            local PRIORITY="$1"
            local MESSAGE="$2"
            local TAG="wallpaper-manager"

            # Ensure the priority is valid for logger.
            case "$PRIORITY" in
              "info" | "information") # Informational messages.
                LEVEL="info"
                ;;
              "error" | "critical" | "err" | "crit") # Error messages.
                LEVEL="err"
                ;;
              "warning" | "warn") # Warning messages.
                LEVEL="warning"
                ;;
              *) # Unknown messages.
                LEVEL="info"
                PRIORITY="info"
                ;;
            esac

            logger -t "''${TAG:-wallpaper-manager}" -p "''${LEVEL:-info}" "''${MESSAGE}"

            return 0
          }

          function generate_wallpaper_list() {
            log "info" "Generating wallpaper list"

            if [[ ! -d "$WALLPAPER_DIR" ]]; then
              log "error" "Wallpaper directory does not exist: ''${WALLPAPER_DIR}"
              return 1
            fi

            log "info" "Debug: Wallpaper directory exists: ''${WALLPAPER_DIR}"

            # Check directory permissions and contents
            log "info" "Debug: Directory permissions: $(ls -ld "''${WALLPAPER_DIR}")"
            log "info" "Debug: Directory contents count: $(find "''${WALLPAPER_DIR}" -maxdepth 1 -print0 2>/dev/null | tr -d '\0' | wc -l)"

            # List some files to see what's in the directory
            log "info" "Debug: Sample files in directory:"
            find "''${WALLPAPER_DIR}" -maxdepth 1 -print0 2>/dev/null | tr -d '\0' | head -5 | while IFS= read -r file; do
              log "info" "Debug:   $file"
            done

            # Test find command step by step
            log "info" "Debug: Testing find command..."

            # First, test basic find
            FIND_OUTPUT=$(find "''${WALLPAPER_DIR}" -type f 2>&1 | head -5)
            log "info" "Debug: Basic find output (first 5 files): $FIND_OUTPUT"

            # Test find with image extensions (recursive search)
            log "info" "Debug: Testing recursive find command..."

            # First, let's see what the symlink resolves to
            REAL_DIR=$(readlink -f "''${WALLPAPER_DIR}")
            log "info" "Debug: Symlink resolves to: ''${REAL_DIR}"

            # Test find on the real directory
            log "info" "Debug: Testing find on real directory: ''${REAL_DIR}"
            IMAGE_FILES=$(find "''${REAL_DIR}" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.gif" -o -name "*.bmp" -o -name "*.tiff" \) 2>&1 | wc -l)
            log "info" "Debug: Found ''${IMAGE_FILES} image files (recursive search)"

            # Show some sample image files found
            log "info" "Debug: Sample image files found:"
            find "''${REAL_DIR}" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.gif" -o -name "*.bmp" -o -name "*.tiff" \) > "/tmp/sample_files_$$" 2>/dev/null || true
            if [[ -s "/tmp/sample_files_$$" ]];
            then
              head -5 "/tmp/sample_files_$$" | while IFS= read -r file;
              do
                log "info" "Debug:   $file"
              done
              rm -f "/tmp/sample_files_$$"
            fi

            if [[ ''${IMAGE_FILES} -eq 0 ]];
            then
              log "error" "No image files found in ''${WALLPAPER_DIR} (including subdirectories)"
              return 1
            fi

            # Now try the full command with better error handling
            log "info" "Debug: Running full recursive find command..."

            # Create a temporary file first
            TEMP_LIST="/tmp/wallpapers_temp_$$"

            if ! find "''${REAL_DIR}" \
              -type f \
              \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \
              -o -name "*.webp" -o -name "*.gif" -o -name "*.bmp" \
              -o -name "*.tiff" \) > "''${TEMP_LIST}" 2>&1;
            then
              log "error" "Failed to find image files"
              log "error" "Debug: find command error: $(cat "''${TEMP_LIST}")"
              rm -f "''${TEMP_LIST}"
              return 1
            fi

            # Check if we got any files
            if [[ ! -s "''${TEMP_LIST}" ]];
            then
              log "error" "No image files found by find command"
              rm -f "''${TEMP_LIST}"
              return 1
            fi

            # Now shuffle and limit to 100
            if ! shuf -n 100 "''${TEMP_LIST}" > "''${SWWW_LIST_FILE}";
            then
              log "error" "Failed to shuffle wallpaper list"
              rm -f "''${TEMP_LIST}"
              return 1
            fi

            # Clean up temp file
            rm -f "''${TEMP_LIST}"

            # Check if we got any wallpapers
            if [[ ! -s "''${SWWW_LIST_FILE}" ]];
            then
              log "error" "No wallpaper files found in ''${WALLPAPER_DIR}"
              log "error" "Debug: Generated file is empty or missing"
              return 1
            fi

            log "info" "Generated wallpaper list with $(wc -l < "''${SWWW_LIST_FILE}") images"
          }

          function cleanup() {
            log "info" "Received signal, cleaning up wallpaper manager..."

            # Remove wallpaper list file
            rm -f "''${SWWW_LIST_FILE}" || true

            exit 0
          }

          ##################################################
          # Pre-flight checks
          ##################################################

          log "info" "Starting wallpaper manager service"

          # Check if wallpaper directory exists
          if [[ ! -d "''${WALLPAPER_DIR}" ]];
          then
            log "error" "Error: Wallpaper directory does not exist: ''${WALLPAPER_DIR}"
            log "error" "Please create the directory or set XDG_WALLPAPERS_DIR environment variable"
            exit 1
          else
            log "info" "Wallpaper directory exists: ''${WALLPAPER_DIR}"
          fi

          # Make sure the state directory exists or create it
          if ! mkdir -p "''${SWWW_STATE_DIR}";
          then
            log "error" "Failed to create state directory: ''${SWWW_STATE_DIR}"
            exit 1
          else
            log "info" "Wallpaper state directory created at ''${SWWW_STATE_DIR}"
          fi

          # Set up signal handlers for graceful cleanup
          trap cleanup INT TERM EXIT
          log "info" "Signal trap set for cleanup"

          ##################################################
          # Wait for swww-daemon to be ready
          ##################################################

          log "info" "Waiting for swww-daemon..."

          NUM_ATTEMPTS=30
          i=1
          while [[ $i -le ''${NUM_ATTEMPTS} ]];
          do
            log "info" "Waiting for swww-daemon... (attempt $i/''${NUM_ATTEMPTS})"

            if systemctl --user is-active --quiet wallpaper-manager-daemon;
            then
              log "info" "wallpaper-manager-daemon service is active"
              break
            else
              log "info" "wallpaper-manager-daemon service is not active"
            fi

            if [[ $i -eq $NUM_ATTEMPTS ]];
            then
              log "error" "Timeout waiting for wallpaper-manager-daemon service to be active"
              exit 1
            fi

            log "info" "Waiting for daemon service... (attempt $i/''${NUM_ATTEMPTS})"
            sleep 1
            i=$((i + 1))
          done

          # Auto-detect Wayland environment variables (same logic as daemon script)
          if [[ "''${WAYLAND_DISPLAY:-EMPTY}" == "EMPTY" ]];
          then
            log "info" "Auto-detecting WAYLAND_DISPLAY"
            NUM_ATTEMPTS=10
            i=1
            while [[ $i -le ''${NUM_ATTEMPTS} ]];
            do
              log "info" "Checking for wayland-$i socket (attempt $i/''${NUM_ATTEMPTS})"
              if [[ -S "''${XDG_RUNTIME_DIR}/wayland-$i" ]];
              then
                export WAYLAND_DISPLAY="wayland-$i"
                log "info" "Auto-detected WAYLAND_DISPLAY=wayland-$i"
                break
              fi
              i=$((i + 1))
            done
          fi

          # Set additional Wayland environment variables
          if [[ "''${WAYLAND_DISPLAY:-EMPTY}" != "EMPTY" ]];
          then
            # Set swww socket path
            export SWWW_SOCKET="''${XDG_RUNTIME_DIR}/swww-''${WAYLAND_DISPLAY}.socket"
            log "info" "Set SWWW_SOCKET=''${SWWW_SOCKET}"

            # Try to detect Hyprland instance signature
            NUM_ATTEMPTS=10
            i=1
            while [[ $i -le ''${NUM_ATTEMPTS} ]];
            do
              log "info" "Checking for hyprland-instance-''${i} socket (attempt $i/''${NUM_ATTEMPTS})"
              if [[ -S "''${XDG_RUNTIME_DIR}/hyprland-instance-''${i}" ]];
              then
                export HYPRLAND_INSTANCE_SIGNATURE="''${XDG_RUNTIME_DIR}/hyprland-instance-''${i}"
                log "info" "Auto-detected HYPRLAND_INSTANCE_SIGNATURE=''${HYPRLAND_INSTANCE_SIGNATURE}"
                break
              fi
              i=$((i + 1))
            done
          fi

          # Now wait for swww-daemon to be ready
          log "info" "Waiting for swww-daemon to accept connections"

          # Debug: Check environment and socket
          log "info" "Debug: WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-unset}"
          log "info" "Debug: XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-unset}"
          log "info" "Debug: SWWW_SOCKET=''${SWWW_SOCKET:-unset}"

          # Debug: Show all relevant environment variables
          log "info" "Debug: Full environment check:"
          env | grep -E "(WAYLAND|XDG|SWWW|HYPRLAND)" | while IFS= read -r line;
          do
            log "info" "Debug: $line"
          done

          # Check if the socket file exists
          if [[ "''${SWWW_SOCKET:-EMPTY}" != "EMPTY" ]] && [[ -S "''${SWWW_SOCKET}" ]];
          then
            log "info" "Debug: swww socket found at ''${SWWW_SOCKET}"
          else
            log "warning" "Debug: swww socket not found at ''${SWWW_SOCKET}"
            # Try to find the socket dynamically
            NUM_ATTEMPTS=10
            i=1
            while [[ $i -le ''${NUM_ATTEMPTS} ]];
            do
              log "info" "Checking for swww-wayland-$i socket (attempt $i/''${NUM_ATTEMPTS})"
              SOCKET_PATH="''${XDG_RUNTIME_DIR}/swww-wayland-$i.socket"
              if [[ -S "''${SOCKET_PATH}" ]];
              then
                log "info" "Debug: Found swww socket at ''${SOCKET_PATH}"
                export SWWW_SOCKET="''${SOCKET_PATH}"
                break
              fi
              i=$((i + 1))
            done
          fi

          NUM_ATTEMPTS=60
          i=1
          while [[ $i -le ''${NUM_ATTEMPTS} ]];
          do
            log "info" "Waiting for swww-daemon... (attempt $i/''${NUM_ATTEMPTS})"

            if ${pkgs.swww}/bin/swww query >/dev/null 2>&1;
            then
              log "info" "swww-daemon is ready and accepting connections"
              break
            else
              log "info" "swww-daemon not ready yet (attempt $i/''${NUM_ATTEMPTS})"
            fi

            if [[ $i -eq ''${NUM_ATTEMPTS} ]];
            then
              log "error" "Timeout waiting for swww-daemon to be ready"
              log "error" "Debug: Final environment check - WAYLAND_DISPLAY=''${WAYLAND_DISPLAY}, XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR}"
              log "error" "Debug: Socket check - SWWW_SOCKET=''${SWWW_SOCKET}"
              exit 1
            fi

            sleep 1
            i=$((i + 1))
          done

          ##################################################
          # Main wallpaper loop
          ##################################################

          log "info" "Querying displays"

          # Debug: Test swww query directly
          log "info" "Debug: Testing swww query command"
          if ${pkgs.swww}/bin/swww query >/dev/null 2>&1;
          then
            log "info" "Debug: swww query command succeeded"
          else
            log "error" "Debug: swww query command failed"
          fi

          # Debug: Show raw output
          log "info" "Debug: Raw swww query output:"
          ${pkgs.swww}/bin/swww query 2>&1 | while IFS= read -r line;
          do
            log "info" "Debug: $line"
          done

          # Now try to get display list
          log "info" "Debug: Attempting to extract display list"
          DISPLAY_LIST=$(${pkgs.swww}/bin/swww query 2>/dev/null | grep -Po "^[^:]+" || true)
          log "info" "Debug: DISPLAY_LIST=''${DISPLAY_LIST:-EMPTY}"

          if [[ "''${DISPLAY_LIST:-EMPTY}" == "EMPTY" ]];
          then
            log "error" "No displays found. Is swww-daemon running?"
            log "error" "Debug: Environment check - WAYLAND_DISPLAY=''${WAYLAND_DISPLAY}, SWWW_SOCKET=''${SWWW_SOCKET}"
            exit 1
          fi
          log "info" "Found displays:"
          while IFS= read -r DISPLAY;
          do
            [[ "''${DISPLAY:-EMPTY}" != "EMPTY" ]] && log "info" "  - ''${DISPLAY}"
          done <<< "''${DISPLAY_LIST}"

          while true;
          do
            log "info" "Starting wallpaper loop"

            # Generate a new list of wallpapers
            if ! generate_wallpaper_list;
            then
              log "error" "Failed to generate wallpaper list, retrying in 60 seconds"
              sleep 60
              continue
            fi

            log "info" "Reading wallpaper list"

            # Read all images into an array first
            if ! mapfile -t IMAGES < "$SWWW_LIST_FILE";
            then
              log "error" "Failed to read wallpaper list"
              sleep 60
              continue
            fi

            if [[ ''${#IMAGES[@]} -eq 0 ]];
            then
              log "error" "No wallpapers found in list"
              sleep 60
              continue
            fi

            log "info" "Setting wallpapers"

            # Set the wallpaper for each display
            IMAGE_INDEX=0
            while IFS= read -r DISPLAY;
            do
              if [[ "''${DISPLAY:-EMPTY}" == "EMPTY" ]];
              then
                log "warning" "No display found, skipping loop"
                continue
              fi

              if [[ "''${IMAGE_INDEX}" -ge ''${#IMAGES[@]} ]];
              then
                log "warning" "Not enough images for all displays, reusing first image"
                IMAGE="''${IMAGES[0]}"
              else
                IMAGE="''${IMAGES[IMAGE_INDEX]}"
              fi

              log "info" "Setting image ''${IMAGE} for display: ''${DISPLAY}"
              if [[ -f "''${IMAGE}" ]];
              then
                # Run swww command and capture exit status without triggering trap
                if ${pkgs.swww}/bin/swww img --resize="$RESIZE_TYPE" --outputs "''${DISPLAY}" "''${IMAGE}";
                then
                  log "info" "Successfully set wallpaper for ''${DISPLAY} to ''${IMAGE}"
                else
                  log "error" "Failed to set wallpaper for ''${DISPLAY} to ''${IMAGE}"
                fi
              else
                log "error" "Image file not found: ''${IMAGE}"
              fi

              IMAGE_INDEX=$((IMAGE_INDEX + 1))
            done <<< "''${DISPLAY_LIST}"

            log "info" "Sleeping for ''${INTERVAL} seconds"

            sleep "''${INTERVAL}"
          done
        '';
      };
    };
  };
}
