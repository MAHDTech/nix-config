{config, ...}: {
  home.file = {
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

        if type rclone >/dev/null 2>&1;
        then
          RCLONE_ENABLED=true
          RSYNC_ENABLED=false
        else
          RCLONE_ENABLED=false
          if type rsync >/dev/null 2>&1;
          then
            RSYNC_ENABLED=true
          else
            RSYNC_ENABLED=false
          fi
        fi

        if [[ "''${RCLONE_ENABLED:-false}" == "false" && "''${RSYNC_ENABLED:-false}" == "false" ]];
        then
          echo "You need either have rclone or rsync installed"
          exit 1
        fi

        case "''${OS_LAYER:-EMPTY}" in

          "crostini" )

            PROJECTS_LOCAL="''${HOME}/Projects/"

            RSYNC_PROJECTS_REMOTE="/mnt/chromeos/GoogleDrive/MyDrive/Projects/Backup/"

            RCLONE_PROJECTS_REMOTE="gdrive:Projects/Backup/"
            RCLONE_BACKUP_REMOTE="gdrive:Backup/rclone"

          ;;

          "wsl" )

            PROJECTS_LOCAL="''${HOME}/Projects/"

            RSYNC_PROJECTS_REMOTE="/mnt/g/My Drive/Projects/Backup/"

            RCLONE_PROJECTS_REMOTE="gdrive:Projects/Backup/"
            RCLONE_BACKUP_REMOTE="gdrive:Backup/rclone"

          ;;

          * )

            # If not a layer, what OS?
            case "''${OS_NAME:-EMPTY}" in

              "nixos" )

                # NixOS needs to have insync installed.
                if ! type insync 2>/dev/null;
                then
                  echo "On NixOS, insync needs to be installed"
                  exit 2
                fi

                PROJECTS_LOCAL="''${HOME}/Projects/"

                RSYNC_PROJECTS_REMOTE="''${HOME}/Insync/mahdtech@gmail.com/Google Drive/Projects/Backup/"

                RCLONE_PROJECTS_REMOTE="gdrive:Projects/Backup/"
                RCLONE_BACKUP_REMOTE="gdrive:Backup/rclone"

              ;;

              * )

                echo "Unknown OS Layer ''${OS_LAYER:-EMPTY} and unsupported OS ''${OS_NAME:-EMPTY}"
                exit 1

              ;;

            esac

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

          if [[ "''${RSYNC_ENABLED:-false}" == "true" ]];
          then
            if [[ ! -d "''${RSYNC_PROJECTS_REMOTE}" ]]; then
              writeLog "ERROR" "The remote projects directory does not exist"
              return 1
            else
              writeLog "DEBUG" "The remote projects directory exists"
            fi
          fi

          return 0

        }

        function backupProjects() {

          if [[ "''${RCLONE_ENABLED:-false}" == "true" ]];
          then
            backupProjectsRclone || return 1
          fi

          if [[ "''${RSYNC_ENABLED:-false}" == "true" ]];
          then
            backupProjectsRsync || return 1
          fi

          return 0

        }

        function backupProjectsRclone() {

          read -rp "This will backup using rclone from ''${PROJECTS_LOCAL} to ''${RCLONE_PROJECTS_REMOTE}. Are you sure? (y/n) " -n 1 -r
          echo
          if [[ ! "''${REPLY:-n}" =~ ^[Yy]$ ]];
          then
            writeLog "ERROR" "User cancelled backup"
            return 1
          fi

          # Make sure rclone is installed.
          if ! type rclone >/dev/null 2>&1; then
            writeLog "ERROR" "Please install rclone"
            return 1
          fi

          rclone sync \
            "''${PROJECTS_LOCAL}" \
            "''${RCLONE_PROJECTS_REMOTE}" \
            --backup-dir "''${RCLONE_BACKUP_REMOTE}/$(date +%Y-%m-%d_%H-%M-%S)-backup" \
            --checksum \
            --ignore-times \
            --track-renames \
            --copy-links \
            --retries-sleep 30s \
            --exclude=".devenv/**" \
            --exclude=".direnv/**" \
            --exclude="node_modules/**" \
            --verbose \
          || {
            writeLog "ERROR" "Failed to backup projects"
            return 1
          }

          return 0

        }

        function backupProjectsRsync() {

          read -rp "This will backup using rsync from ''${PROJECTS_LOCAL} to ''${RSYNC_PROJECTS_REMOTE}. Are you sure? (y/n) " -n 1 -r
          echo
          if [[ ! "''${REPLY:-n}" =~ ^[Yy]$ ]];
          then
            writeLog "ERROR" "User cancelled backup"
            return 1
          fi

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
            --exclude="node_modules" \
            "''${PROJECTS_LOCAL}" \
            "''${PROJECTS_REMOTE}" \
          || {
            writeLog "ERROR" "Failed to backup projects"
            return 1
          }

          return 0

        }

        function restoreProjects() {

          if [[ "''${RCLONE_ENABLED:-false}" == "true" ]];
          then
            restoreProjectsRclone || return 1
          fi

          if [[ "''${RSYNC_ENABLED:-false}" == "true" ]];
          then
            restoreProjectsRsync || return 1
          fi

          return 0

        }

        function restoreProjectsRclone() {

          read -rp "This will restore using rclone from ''${RCLONE_PROJECTS_REMOTE} to ''${PROJECTS_LOCAL}. Are you sure? (y/n) " -n 1 -r
          echo
          if [[ ! "''${REPLY:-n}" =~ ^[Yy]$ ]];
          then
            writeLog "ERROR" "User cancelled restore"
            return 1
          fi

          # Make sure rclone is installed.
          if ! type rclone >/dev/null 2>&1; then
            writeLog "ERROR" "Please install rclone"
            return 1
          fi

          rclone sync \
            "''${RCLONE_PROJECTS_REMOTE}" \
            "''${PROJECTS_LOCAL}" \
            --backup-dir "''${RCLONE_BACKUP_REMOTE}/$(date +%Y-%m-%d_%H-%M-%S)-restore" \
            --checksum \
            --ignore-times \
            --track-renames \
            --copy-links \
            --retries-sleep 30s \
            --exclude=".devenv/**" \
            --exclude=".direnv/**" \
            --exclude="node_modules/**" \
            --verbose \
          || {
            writeLog "ERROR" "Failed to restore projects"
            return 1
          }

        }

        function restoreProjectsRsync() {

          read -rp "This will restore using rsync from ''${RSYNC_PROJECTS_REMOTE} to ''${PROJECTS_LOCAL}. Are you sure? (y/n) " -n 1 -r
          echo
          if [[ ! "''${REPLY:-n}" =~ ^[Yy]$ ]];
          then
            writeLog "ERROR" "User cancelled restore"
            return 1
          fi

          # Make sure rsync is installed.
          if ! type rsync >/dev/null 2>&1; then
            writeLog "ERROR" "Please install rsync"
            return 1
          fi

          # Run rsync to restore the projects.
          rsync \
            --progress \
            --archive \
            --verbose \
            --human-readable \
            --partial \
            --exclude=".devenv" \
            --exclude=".direnv" \
            --exclude=".git" \
            --exclude="node_modules" \
            "''${RSYNC_PROJECTS_REMOTE}" \
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
