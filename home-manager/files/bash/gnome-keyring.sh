#!/usr/bin/env bash

##################################################
# Name: gnome-keyring
# Description: GNOME Keyring shennanigans.
##################################################

function set_vars_gnome_keyring() {

	# Control
	export GNOME_KEYRING_CONTROL="${GNOME_KEYRING_CONTROL:=/run/user/$(id --user)/keyring}"

	# Local
	export GNOME_KEYRING_LOCAL="${GNOME_KEYRING_LOCAL:=$HOME/.local/share/keyrings}"

	# SSH
	export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:=/run/user/$(id --user)/keyring/ssh}"

	# GPG
	#export GPG_AGENT_INFO="${GPG_AGENT_INFO:=/run/user/$(id --user)/keyring/gpg:0:1}"

	return 0

}

function start_gnome_keyring() {

	if type gnome-keyring 1>/dev/null 2>&1; then

		writeLog "DEBUG" "GNOME keyring is installed"

		set_vars_gnome_keyring || {
			writeLog "ERROR" "Failed to set variables needed for gnome-keyring"
			return 1
		}

		if ! pgrep --full gnome-keyring-daemon; then

			writeLog "INFO" "Starting gnome-keyring-daemon"

			# Home Manager now manages gnome-keyring as a systemd unit
			if type home-manager >/dev/null 2>&1; then

				systemctl --user --restart gnome-keyring.service || {
					writeLog "ERROR" "Failed to start the gnome-keyring user service"
					return 1
				}

			# Legacy
			else

				gnome-keyring-daemon \
					--start \
					--daemonize \
					--components=pkcs11,secrets,ssh || {
					writeLog "ERROR" "Failed to start GNOME keyring daemon"
					return 1
				}
			fi

		else

			writeLog "INFO" "GNOME keyring daemon is already running"

		fi

		if [[ ! -d ${GNOME_KEYRING_LOCAL} ]]; then
			mkdir --parents "${GNOME_KEYRING_LOCAL}" || {
				writeLog "ERROR" "Failed to create local gnome-keyring directory"
			}
		fi

		dbus-update-activation-environment --systemd DISPLAY || {
			writeLog "ERROR" "Failed to update dbus for GNOME Keyring"
		}

	else

		writeLog "WARNING" "Gnome Keyring is not installed!"

	fi

	return 0

}
