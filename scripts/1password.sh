#!/usr/bin/env bash

set -euo pipefail

# Import functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

function install_1password() {

  writeLog "INFO" "Installing 1Password GUI and CLI"

  writeLog "INFO" "Importing 1Password GPG key"
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg || {
    writeLog "ERROR" "Failed to import 1Password GPG key"
    return 1
  }

  writeLog "INFO" "Adding 1Password repository"
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list || {
    writeLog "ERROR" "Failed to add 1Password repository"
    return 1
  }

  writeLog "INFO" "Importing 1Password debsig policy"
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ || {
    writeLog "ERROR" "Failed to create 1Password debsig policy"
    return 1
  }
  
  writeLog "INFO" "Importing 1Password debsig policy"
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol || {
    writeLog "ERROR" "Failed to import 1Password GPG key"
    return 1
  }

  writeLog "INFO" "Importing 1Password debsig key"
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 || {
    writeLog "ERROR" "Failed to create 1Password debsig keyring"
    return 1
  }

  curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg || {
    writeLog "ERROR" "Failed to import 1Password debsig key"
    return 1
  }

  writeLog "INFO" "Updating apt cache"
  sudo apt update || {
    writeLog "ERROR" "Failed to update apt cache"
    return 1
  }
  
  writeLog "INFO" "Installing 1Password CLI"
  sudo apt install --yes \
    1password \
    1password-cli \
  || {
    writeLog "ERROR" "Failed to install 1Password GUI and CLI"
    return 1
  }

  return 0

}

install_1password || {
  writeLog "ERROR" "Failed to install 1Password GUI and CLI"
  exit 1
}
