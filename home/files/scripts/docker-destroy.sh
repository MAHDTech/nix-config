#!/usr/bin/env bash

set -e
set -u
set -o pipefail

export DOCKER_COMMAND="docker"

if type podman >/dev/null 2>&1; then
	DOCKER_COMMAND="podman"
fi

if [[ ${1-} ]]; then
	FORCE=$1
fi

# Stop all running containers if force is enabled
if [[ ${FORCE:-FALSE} == "FORCE" ]]; then
	$DOCKER_COMMAND stop $($DOCKER_COMMAND ps -a -q) >/dev/null 2>&1 || {
		echo "Failed to stop running containers, skipping..."
	}
fi

echo -e "\nBEFORE:\n"
$DOCKER_COMMAND system df

# Remove stopped containers
$DOCKER_COMMAND rm $($DOCKER_COMMAND ps -a -q) >/dev/null 2>&1 || {
	echo "Failed to remove stopped containers, skipping..."
}

# Prune all unused images
$DOCKER_COMMAND system prune --all --force --volumes || {
	echo "Failed to prune unused images, skipping..."
}

echo -e "\nAFTER:\n"
$DOCKER_COMMAND system df

exit 0
