#!/usr/bin/env bash

##################################################
# Name: variables
# Description: Variables specific to the env
#
# IMPORTANT: The populated file should not be stored in git.
#
##################################################

#########################
# Logging
#########################

# Receive less prompts but more YOLO
export ENABLE_YOLO_MODE="FALSE"

# The global log level
export LOG_LEVEL="INFO"

# Override the log destination if required.
export LOG_DESTINATION="file"

#########################
# Common
#########################

# A description for the platform you are working on, defaults to OS based.
export PLATFORM="${VARIANT:=$OS_NAME}"

# A list of all the environments, each representing a separate SSH key.
export ENVS=(
    "${USER}"
)

export DOMAIN=""

#########################
# SSH
#########################

# Use Trezor or OpenSSH?
export ENABLED_SSH_AGENT="openssh"

# OpenSSH Keys will be named ${PLATFORM^^}_${ENV^^}_${KEY_TYPE^^}
#export KEY_TYPE="ed25519-sk"
export KEY_TYPE="ed25519"

#########################
# GPG
#########################

# Use GnuPG, Trezor, KeepKey, Ledger?
export ENABLED_GPG_AGENT="gnupg"

#########################
# AWS
#########################

export AWS_DEFAULT_OUTPUT="yaml"

#########################
# Nix
#########################

# Install Nix and Home Manager?
export NIX_ENABLED="FALSE"

# Where is the Nix profile
export NIX_PROFILE_SCRIPT_USER="${HOME}/.nix-profile/etc/profile.d/nix.sh"
export NIX_PROFILE_SCRIPT_MACHINE="/etc/profile.d/nix.sh"

#########################
# Kubernetes
#########################

# An associative array of Kubernetes Clusters, Per-Environment
#declare -A K8S_CLUSTERS=(
#["ENV1"]="CLUSTER1,CLUSTER2"
#["ENV2"]="CLUSTER1,CLUSTER2"
#)

# An associative array of Kubernetes Contexts, Per-Environment
#declare -A K8S_CONTEXTS=(
#["ENV1"]="CLUSTER1,CLUSTER2"
#["ENV2"]="CLUSTER1,CLUSTER2"
#)

# An associative array of Kubernetes Users, Per-Environment
#declare -A K8S_USERS=(
#["ENV1"]="CLUSTER1,CLUSTER2"
#["ENV2"]="CLUSTER1,CLUSTER2"
#)

#########################
# Proxy
#########################

# Environment wide Proxy servers
export HTTP_PROXY=""
export HTTPS_PROXY=""
export http_proxy=""
export https_proxy=""

# Proxy for Golang packages
export GOPROXY="https://proxy.golang.org,direct"

#########################
# Other
#########################

# GitHub
export GITHUB_TOKEN=""

# GitLab
export GITLAB_TOKEN=""

# Wakatime
export WAKATIME_API_KEY=""
export WAKATIME_DEBUG="false"
