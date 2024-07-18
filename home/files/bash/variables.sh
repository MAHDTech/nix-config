#!/usr/bin/env bash

##################################################
# Name: variables
# Description: Variables loaded into the shell at startup
##################################################

# The editor
export EDITOR="vim"

########################################
# Logging
########################################

# Some older external scripts look for the debug variable
# NOTE: Go programs look if the variable is defined, even if FALSE!
#export DEBUG="FALSE"

########################################
# Users
########################################

export WIN_USER="mahdtech"
export LIN_USER="${USER}"

########################################
# Flatpaks
########################################

# Enable flatpak extensions in Visual Studio Code
export FLATPAK_ENABLE_SDK_EXT="rust,golang"

########################################
# Python
########################################

PYTHONVERSION="$(python3 -c 'import sys; print(str(sys.version_info[0])+"."+str(sys.version_info[1]))' 2</dev/null)"

if [[ "${PYTHON_VERSION:-EMPTY}" ]]; then
	# NOTE: Flatpaks have old python, set a default
	export PYTHONVERSION="3.9"

fi

export PYTHONPATH="${HOME}/.local/lib/python${PYTHONVERSION}/site-packages"

########################################
# Colours
########################################

# Colour GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Foreground Colours

declare -x fgRed
fgRed="\001$(tput setaf 1)\002"

declare -x fgGreen
fgGreen="\001$(tput setaf 2)\002"

declare -x fgBlue
fgBlue="\001$(tput setaf 4)\002"

declare -x fgMagenta
fgMagenta="\001$(tput setaf 5)\002"

declare -x fgYellow
fgYellow="\001$(tput setaf 3)\002"

declare -x fgCyan
fgCyan="\001$(tput setaf 6)\002"

declare -x fgWhite
fgWhite="\001$(tput setaf 7)\002"

declare -x fgBlack
fgBlack="\001$(tput setaf 0)\002"

# Background Colours

declare -x bgRed
bgRed="\001$(tput setab 1)\002"

declare -x bgGreen
bgGreen="\001$(tput setab 2)\002"

declare -x bgBlue
bgBlue="\001$(tput setab 4)\002"

declare -x bgMagenta
bgMagenta="\001$(tput setab 5)\002"

declare -x bgYellow
bgYellow="\001$(tput setab 3)\002"

declare -x bgCyan
bgCyan="\001$(tput setab 6)\002"

declare -x bgWhite
bgWhite="\001$(tput setab 7)\002"

declare -x bgBlack
bgBlack="\001$(tput setab 0)\002"

# Other Colours

declare -x bgBlink
bgBlink="\001$(tput blink)\002"

# Reset

declare -x fgReset
fgReset="\001$(tput sgr0)\002"

declare -x bgReset
bgReset="\001$(tput sgr0)\002"

########################################
# Wayland / X11
########################################

export LIBGL_ALWAYS_INDIRECT=0

export QT_QPA_PLATFORM=wayland
export XDG_SESSION_TYPE=wayland

case "${OS_LAYER:-UNKNOWN}" in

"WSL")

	DISPLAY=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -n1):0.0
	export DISPLAY

	;;

"Crostini")

	export DISPLAY=":0"
	export XAUTHORITY="${HOME}/.Xauthority"

	# Allow the root user to display GUI apps in my wayland session
	xhost +SI:localuser:root

	# Allow all local users
	#xhost +local

	# YOLO allow everybody
	#xhost +

	;;

"TOOLBOX")

	export DISPLAY=":0"

	;;

"Silverblue")

	export DISPLAY="localhost:0"

	;;

*)

	# Default
	export DISPLAY=":0"

	;;

esac

########################################
# Systemd
########################################

# Disable systemctl auto-paging feature
export SYSTEMD_PAGER=""

# Define the editor to be used by systemd
export SYSTEMD_EDITOR="vim"

########################################
# Go
########################################

# The path to the go workspace
export GOPATH="${HOME}/go"
export GOBIN="${GOPATH}/bin"

# Auto Go Modules allows both go get to work and local modules if go.mod is present.
export GO111MODULE="auto"

########################################
# Docker
########################################

# Local Docker configuration
#export DOCKER_HOST=tcp://127.0.0.1:2375

export DOCKER_BUILDKIT=1

# Docker (System Daemon)
export DOCKER_ROOTLESS=FALSE
export DOCKER_HOST=unix:///var/run/docker.sock

# Docker (User Daemon)
#export DOCKER_ROOTLESS=TRUE
#export XDG_RUNTIME_DIR=/run/user/${UID}
#export PATH=/usr/bin:$PATH
#export DOCKER_HOST=unix:///run/user/${UID}/docker.sock

########################################
# SSH
########################################

# NOTE: SSH is now managed with Home Manager

# When using GPG agent with SSH enabled.
#export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

########################################
# GPG
########################################

# NOTE: GNUPGHOME is managed with Home Manger.

GPG_TTY=$(tty)
export GPG_TTY

########################################
# Git
########################################

#export GIT_SSH_COMMAND="ssh -v"

# Allow git to ask for a username and password
export GIT_TERMINAL_PROMPT=1

export REVIEW_BRANCH="trunk"
export DEFAULT_BRANCH="trunk"

########################################
# Bash History
########################################

# Hide commands that start with a space from the bash history
#export HISTCONTROL=ignorespace

# Don't put duplicate lines or lines starting with space in the history.
export HISTCONTROL=ignoreboth

# Add the Date and Time to the History
export HISTTIMEFORMAT="%d/%m/%y %T "

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
export HISTSIZE=10000
export HISTFILESIZE=5000

########################################
# Kubernetes
########################################

# Default kubeconfig
export KUBECONFIG="${HOME}/.kube/config"

# Enable Kubernetes symbol
export KUBE_PS1_SYMBOL_ENABLE="false"

# Kube PS1 Symbol (Unicode u2388 is the wheel)
export KUBE_PS1_SYMBOL_DEFAULT="\u2388"

# If the shell can display images, use this
export KUBE_PS1_SYMBOL_USE_IMG="true"

# Custom function to display context
export KUBE_PS1_CONTEXT_FUNCTION="kubeContext"

# Custom function to display cluster
export KUBE_PS1_CLUSTER_FUNCTION="kubeCluster"

# Custom function to display namespace
export KUBE_PS1_NAMESPACE_FUNCTION="kubeNamespace"

# Colours (black, red, green, yellow, blue, magenta, cyan, white, grey)
export KUBE_PS1_SYMBOL_COLOUR="white"
export KUBE_PS1_CTX_COLOUR="white"
export KUBE_PS1_CLUST_COLOUR="yellow"
export KUBE_PS1_NS_COLOUR="green"
export KUBE_PS1_BG_COLOUR="blue"

########################################
# Homebrew
########################################

# https://github.com/Homebrew/brew/blob/7d31a70373edae4d8e78d91a4cbc05324bebc3ba/Library/Homebrew/manpages/brew.1.md.erb#L202

export HOMEBREW_EDITOR="vim"
export HOMEBREW_AUTO_UPDATE_SECS="3600"
export HOMEBREW_NO_AUTO_UPDATE="False"
export HOMEBREW_NO_ANALYTICS="True"
export HOMEBREW_VERSION="True"

########################################
# Rust
########################################

#export PKG_CONFIG_PATH="/usr/local/Cellar/openal-soft/1.20.1/lib/pkgconfig"

########################################
# Starship
#######################################

export STARSHIP_CONFIG="${HOME}/.config/starship.toml"
export STARSHIP_CACHE="${HOME}/.cache/starship"

########################################
# CodeQL
#######################################

export CODEQL_DOTFILES="True"
export CODEQL_SETUP_SUBMODULES="True"

########################################
# Other
########################################

# EOF
