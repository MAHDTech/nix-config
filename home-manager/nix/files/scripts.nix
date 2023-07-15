{config, ...}: {
  home.file = {
    "docker-destroy" = {
      target = "${config.home.homeDirectory}/.local/bin/docker-destroy";
      executable = true;

      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        if [[ ''${1-} ]]; then
          FORCE=$1
        fi

        # Stop all running containers if force is enabled
        if [[ "''${FORCE:-FALSE}" == "FORCE" ]]; then
          docker stop $(docker ps -a -q) >/dev/null 2>&1 || {
            echo "Failed to stop running containers, skipping..."
          }
        fi

        echo -e "\nBEFORE:\n"
        docker system df

        # Remove stopped containers
        docker rm $(docker ps -a -q) >/dev/null 2>&1 || {
          echo "Failed to remove stopped containers, skipping..."
        }

        # Prune all unused images
        docker system prune --all --force --volumes || {
          echo "Failed to prune unused images, skipping..."
        }

        # If force was on, remove volumes as well.
        if [[ "''${FORCE:-FALSE}" == "FORCE" ]]; then
          for VOLUME in docker volume ls --output json | jq -r .Name;
          do
            echo "Removing volume $VOLUME"
            docker volume rm $VOLUME || {
              echo "Failed to remove volume $VOLUME, skipping..."
            }
          done

        echo -e "\nAFTER:\n"
        docker system df

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
  };
}
