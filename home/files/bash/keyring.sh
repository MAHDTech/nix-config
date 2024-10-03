#!/usr/bin/env bash

##################################################
# Name: keyring
# Description: Keyring shennanigans.
##################################################

function unlock_gnome_keyring() {

	local UNLOCK_PASSWORD

	echo ""
	read -rsp "Enter GNOME keyring unlock password: " UNLOCK_PASSWORD

	export "$(echo -n "$UNLOCK_PASSWORD" | gnome-keyring-daemon --replace --unlock)"

	unset UNLOCK_PASSWORD

	return 0

}

function setup_gnome_keyring() {

	if [[ ${GNOME_KEYRING_CONTROL:EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "The variable GNOME_KEYRING_CONTROL is empty!"
		return 1
	fi

	if [[ ${GNOME_KEYRING_LOCAL:EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "The variable GNOME_KEYRING_LOCAL is empty!"
		return 1
	fi

	# Is SSH enabled in GNOME Keyring?
	if [[ -S "${XDG_RUNTIME_DIR}/keyring/ssh" ]]; then
		writeLog "DEBUG" "GNOME Keyring SSH socket is enabled"
		export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:=$GNOME_KEYRING_CONTROL/ssh}"
	fi

	# Is GPG enabled in GNOME Keyring?
	if [[ -S "${XDG_RUNTIME_DIR}/keyring/gpg" ]]; then
		writeLog "DEBUG" "GNOME Keyring GPG socket is enabled"
		export GPG_AGENT_INFO="${GPG_AGENT_INFO:=$GNOME_KEYRING_CONTROL/gpg:0:1}"
	fi

	if [[ ! -d ${GNOME_KEYRING_LOCAL} ]]; then
		mkdir --parents "${GNOME_KEYRING_LOCAL}" || {
			writeLog "ERROR" "Failed to create local gnome-keyring directory"
		}
	fi

	return 0

}

function start_keyring() {

	export ENABLED_KEYRING_AGENT="${ENABLED_KEYRING_AGENT:-none}"
	export XDG_RUNTIME_DIR
	export GNOME_KEYRING_CONTROL
	export GNOME_KEYRING_LOCAL

	# XDG_RUNTIME_DIR is set by systemd or defaults to /run/user/<uid>
	XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:=/run/user/$(id --user)}"

	# GNOME_KEYRING_CONTROL is set by GNOME Keyring or defaults to /run/user/<uid>/keyring
	GNOME_KEYRING_CONTROL="${GNOME_KEYRING_CONTROL:=$XDG_RUNTIME_DIR/keyring}"

	# GNOME_KEYRING_LOCAL is set by GNOME Keyring or default to $HOME/.local/share/keyrings
	GNOME_KEYRING_LOCAL="${GNOME_KEYRING_LOCAL:=$HOME/.local/share/keyrings}"

	case "${ENABLED_KEYRING_AGENT,,}" in

	"home-manager")

		# If home manager is using gnome-keyring, give it a kick in the guts.
		if type gnome-keyring-daemon 1>/dev/null 2>&1; then

			setup_gnome_keyring || {
				writeLog "ERROR" "Failed to set variables needed for gnome-keyring"
				return 1
			}
			systemctl --user restart gnome-keyring.service || {
				writeLog "ERROR" "Failed to start the gnome-keyring user service"
				return 1
			}

		fi

		;;

	"gnome-keyring")

		if type gnome-keyring-daemon 1>/dev/null 2>&1; then

			setup_gnome_keyring || {
				writeLog "ERROR" "Failed to set variables needed for gnome-keyring"
				return 1
			}

			if ! pgrep --full gnome-keyring-daemon >/dev/null; then

				writeLog "INFO" "Starting GNOME keyring daemon"

				# gpg is now no longer offered by gnome-keyring.
				# ssh is now being used from 1Password instead of gnome-keyring.
				unlock_gnome_keyring || {
					writeLog "ERROR" "Failed to start GNOME keyring daemon"
					return 1
				}

			else

				writeLog "INFO" "GNOME keyring daemon is already running"

			fi

		else

			writeLog "WARNING" "Gnome Keyring is not installed!"

		fi

		;;

	*)

		writeLog "WARN" "Unsupported or no keyring set in ENABLED_KEYRING_AGENT variable: ${ENABLED_KEYRING_AGENT}"

		;;

	esac

	# It was fucking DBUS!
	# Don't remove this, took a while to find this fix!
	dbus-update-activation-environment --systemd --all || {
		writeLog "ERROR" "Failed to update dbus for GNOME Keyring"
	}

	return 0

}
