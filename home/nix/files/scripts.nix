{config, ...}: {
  home.file = {
    "docker-destroy" = {
      target = "${config.home.homeDirectory}/.local/bin/docker-destroy";
      executable = true;

      text = ''
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

        echo -e "\nAFTER:\n"
        docker system df

        exit 0
      '';
    };
  };
}
