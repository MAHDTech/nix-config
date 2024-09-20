{config, ...}: {
  home.file = {
    "cursor-install" = {
      target = "${config.home.homeDirectory}/.local/bin/cursor-install";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        echo "Installing cursor..."

        sudo apt install --yes libfuse2 libnss3 || {
          echo "Failed to install dependencies!"
          exit 1
        }

        mkdir -p ~/Apps || {
          echo "Failed to create directory!"
          exit 2
        }

        wget \
          --output-document ~/Apps/cursor.AppImage \
          "https://downloader.cursor.sh/linux/appImage/x64" || {
            echo "Failed to download cursor"
            exit 3
          }

        chmod +x ~/Apps/cursor.AppImage || {
          echo "Failed to chmod cursor!"
          exit 4
        }

        sudo ln -sf ~/Apps/cursor.AppImage /usr/local/bin/cursor || {
          echo "Failed to symlink cursor!"
          exit 5
        }

        wget \
          --output-document /tmp/cursor.png \
          "https://avatars.githubusercontent.com/u/126759922?v=4" || {
            echo "Failed to download cursor icon!"
            exit 6
          }

        sudo cp /tmp/cursor.png /usr/share/icons/hicolor/256x256/apps/cursor.png || {
          echo "Failed to copy cursor icon!"
          exit 7
        }

        rm /tmp/cursor.png || {
          echo "Failed to remove cursor icon!"
          exit 8
        }

        sudo touch /usr/share/applications/.garcon_trigger || {
          echo "Failed to create garcon trigger!"
          exit 9
        }

        echo "Finished installing cursor!"
        exit 0
      '';
    };

    "docker-tags" = {
      target = "${config.home.homeDirectory}/.local/bin/docker-tags";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        IMAGE=$1
        PAGE_SIZE=100
        PAGE_INDEX=0

        if [[ -z "''${IMAGE:-}" ]];
        then

          cat << EOF
          Usage:

              docker-tags <image>

          Example:

              docker-tags library/ubuntu"
        EOF
          exit 0

        fi

        while true;
        do

          PAGE_INDEX=$((PAGE_INDEX+1))

          RESULTS=$(\
            curl \
              --location \
              --silent \
              "https://registry.hub.docker.com/v2/repositories/''${IMAGE}/tags?page=''${PAGE_INDEX}&page_size=''${PAGE_SIZE}" \
            | jq -r 'select(.results != null) \
            | .results[]["name"]' \
          )

          # shellcheck disable=SC2181
          if [[ $? != 0 ]] || [[ "''${RESULTS:-}" == "" ]];
          then
            break
          fi

          echo "''${RESULTS}"

        done
      '';
    };

    "docker-destroy" = {
      target = "${config.home.homeDirectory}/.local/bin/docker-destroy";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        clear
        set -euo pipefail

        echo "Cleaning up Docker containers, images and volumes..."

        if [[ ''${1-} ]]; then
          FORCE=$1
        fi

        # Stop all running containers if force is enabled
        if [[ "''${FORCE:-NONE}" == "FORCE" ]]; then
          docker stop $(docker ps -a -q) >/dev/null 2>&1 || {
            echo "Failed to stop running containers, skipping..."
          }
        fi

        DOCKER_BEFORE=$(docker system df)

        # Remove stopped containers
        docker rm $(docker ps -a -q) >/dev/null 2>&1 || {
          echo "Failed to remove stopped containers, skipping..."
        }

        # Prune all unused images
        docker system prune --all --force --volumes || {
          echo "Failed to prune unused images, skipping..."
        }

        # Prune all docker volumes (unattached)
        docker volume prune --force || {
          echo "Failed to prune unused volumes, skipping..."
        }

        # Prune buildx cache
        docker buildx prune --force || {
          echo "Failed to prune buildx cache, skipping..."
        }

        # If force was on, remove all volumes as well.
        if [[ "''${FORCE:-NONE}" == "FORCE" ]]; then
          docker volume prune --all --force || {
            echo "Failed to prune all volumes, skipping..."
          }
        fi

        DOCKER_AFTER=$(docker system df)

        echo -e "\nBEFORE:\n"
        echo "''${DOCKER_BEFORE}"

        echo -e "\nAFTER:\n"
        echo "''${DOCKER_AFTER}"

        exit 0
      '';
    };

    "direnv-wrapper" = {
      target = "${config.home.homeDirectory}/.local/bin/flatpak/direnv-wrapper";
      executable = true;

      text = ''
        #!/bin/sh

        exec flatpak-spawn --host direnv "$@"
      '';
    };

    "sync-projects" = {
      target = "${config.home.homeDirectory}/.local/bin/sync-projects";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        ACTION="''${1:-}"

        if [[ "''${ACTION:-EMPTY}" == "EMPTY" ]];
        then
          echo "Please specify an action of 'backup' or 'restore'"
          exit 1
        fi

        case "''${OS_LAYER:-EMPTY}" in

          "crostini" )

            PROJECTS_LOCAL="''${HOME}/Projects/"
            PROJECTS_REMOTE="/mnt/chromeos/GoogleDrive/MyDrive/Projects/Backup/"

          ;;

          "wsl" )

            PROJECTS_LOCAL="''${HOME}/Projects/"
            PROJECTS_REMOTE="/mnt/g/My Drive/Projects/Backup/"

          ;;

          * )

            echo "Unknown OS Layer ''${OS_LAYER:-EMPTY}"
            exit 1

          ;;

        esac

        # shellcheck disable=SC1091
        source "''${HOME}/.config/bash/logging.sh" || {
          echo "Failed to source logging.sh"
          exit 1
        }

        function checkFolders() {

          # Make sure the local and remote directories exist.
          if [[ ! -d "''${PROJECTS_LOCAL}" ]]; then
            writeLog "ERROR" "The local projects directory does not exist"
            return 1
          else
            writeLog "DEBUG" "The local projects directory exists"
          fi

          if [[ ! -d "''${PROJECTS_REMOTE}" ]]; then
            writeLog "ERROR" "The remote projects directory does not exist"
            return 1
          else
            writeLog "DEBUG" "The remote projects directory exists"
          fi

          return 0

        }

        function backupProjects() {

          # Make sure rsync is installed.
          if ! type rsync >/dev/null 2>&1; then
            writeLog "ERROR" "Please install rsync"
            return 1
          fi

          # Run rsync to backup the projects.
          rsync \
            --progress \
            --archive \
            --verbose \
            --human-readable \
            --partial \
            --delete \
            --force \
            --exclude=".devenv" \
            --exclude=".direnv" \
            "''${PROJECTS_LOCAL}" \
            "''${PROJECTS_REMOTE}" \
          || {
            writeLog "ERROR" "Failed to backup projects"
            return 1
          }

          return 0

        }

        function restoreProjects() {

          # Make sure rsync is installed.
          if ! type rsync >/dev/null 2>&1; then
            writeLog "ERROR" "Please install rsync"
            return 1
          fi

          # Run rsync to backup the projects.
          rsync \
            --progress \
            --archive \
            --verbose \
            --human-readable \
            --partial \
            --exclude=".devenv" \
            --exclude=".direnv" \
            "''${PROJECTS_REMOTE}" \
            "''${PROJECTS_LOCAL}" \
          || {
            writeLog "ERROR" "Failed to restore projects"
            return 1
          }

          return 0

        }

        # Make sure the folders exist.
        checkFolders || {
          writeLog "ERROR" "Failed to check folders"
          exit 1
        }

        # Run the action
        case "''${ACTION}" in

          "backup" )
            echo "Starting backup of projects"
            backupProjects || {
              writeLog "ERROR" "Failed to backup projects"
              exit 1
            }
          ;;

          "restore" )
            echo "Starting restore of projects"
            restoreProjects || {
              writeLog "ERROR" "Failed to restore projects"
              exit 1
            }
          ;;

          * )
            echo "Unknown action ''${ACTION}"
            exit 1
          ;;

        esac

        echo "Completed ''${ACTION} of projects"

      '';
    };
  };
}
