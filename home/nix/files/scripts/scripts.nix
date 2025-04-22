{ config, ... }:
{
  home.file = {

    "install-windsurf" = {
      target = "${config.home.homeDirectory}/.local/bin/install-windsurf";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        echo "Installing windsurf..."

        if ! type apt 2>/dev/null;
        then
          writeLog "ERROR" "Windsurf needs Ubuntu/Debian at this time"
          exit 1
        fi

        curl \
          --fail \
          --silent \
          --location \
          --show-error \
          "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | \
          sudo gpg --dearmor -o /usr/share/keyrings/windsurf-stable-archive-keyring.gpg

        echo "deb [signed-by=/usr/share/keyrings/windsurf-stable-archive-keyring.gpg arch=amd64] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | \
        sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null

        sudo apt update

        sudo apt install windsurf

        if [[ "''${OS_NAME:-EMPTY}" == "cros" ]];
        then
          sudo touch /usr/share/applications/.garcon_trigger || {
            echo "Failed to create garcon trigger!"
            exit 9
          }
        fi

        echo "Finished installing windsurf!"
        exit 0
      '';
    };

    "install-cursor" = {
      target = "${config.home.homeDirectory}/.local/bin/install-cursor";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        if [[ "''${OS_NAME:-EMPTY}" == "nixos" ]];
        then
          echo "No, use appimageTools instead!"
          exit 1
        fi

        echo "Installing cursor..."

        if type apt 2>/dev/null;
        then
          sudo apt install --yes libfuse2 libnss3 || {
            echo "Failed to install dependencies!"
            exit 1
          }
        fi

        mkdir -p ~/Apps || {
          echo "Failed to create apps home directory!"
          exit 2
        }

        wget \
          --output-document ~/Apps/cursor.appimage \
          "https://downloader.cursor.sh/linux/appImage/x64" || {
            echo "Failed to download cursor"
            exit 3
          }

        chmod +x ~/Apps/cursor.appimage || {
          echo "Failed to chmod cursor!"
          exit 4
        }

        if [[ "''${OS_NAME:-EMPTY}" == "cros" ]];
        then
          sudo touch /usr/share/applications/.garcon_trigger || {
            echo "Failed to create garcon trigger!"
            exit 9
          }
        fi

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
    "nixos-check-updates" = {
      target = "${config.home.homeDirectory}/.local/bin/nixos-check-updates";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        # This script assumes your flake is in a variable named "DOTFILES_NIX_CONFIG"
        # and that the required functions are available.

        # Source the required functions.
        FUNCTIONS_FILES=(
          ''${HOME}/.config/bash/logging.sh
          ''${HOME}/.config/bash/nix.sh
        )
        for FUNCTIONS_FILE in "''${FUNCTIONS_FILES[@]}";
        do
          source "''${FUNCTIONS_FILE}" || {
            echo "Failed to source ''${FUNCTIONS_FILE}"
            exit 1
          }
        done

        if [[ -z "''${DOTFILES_NIX_CONFIG:-}" ]]; then
          writeLog "ERROR" "DOTFILES_NIX_CONFIG is not set"
          exit 1
        elif [[ ! -d "''${DOTFILES_NIX_CONFIG}" ]]; then
          writeLog "ERROR" "DOTFILES_NIX_CONFIG directory does not exist"
          exit 1
        else
          pushd ''${DOTFILES_NIX_CONFIG} >/dev/null 2>&1 || {
            writeLog "ERROR" "Failed to pushd to DOTFILES_NIX_CONFIG"
            exit 1
          }
        fi

        writeLog "INFO" "Checking for NixOS updates"

        dotfiles update
        dotfiles build

        updates=$(nvd diff /run/current-system ./result | grep -e '\[U' | wc -l)

        alt="updates-pending"

        if [[ $updates -eq 0 ]];
        then

          alt="up-to-date"
          tooltip="NixOS up-to-date"

        elif [[ $updates != 0 ]];
        then

          tooltip=$(cd ''${DOTFILES_NIX_CONFIG} && nvd diff /run/current-system ./result | grep -e '\[U' | awk '{ for (i=3; i<NF; i++) printf $i " "; if (NF >= 3) print $NF; }' ORS='\\n' )

        fi

        echo "{ \"text\":\"$updates\", \"alt\":\"$alt\", \"tooltip\":\"$tooltip\" }"
      '';
    };
  };
}
