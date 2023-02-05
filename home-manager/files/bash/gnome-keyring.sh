#!/usr/bin/env bash

##################################################
# Name: gnome-keyring
# Description: GNOME Keyring shennanigans.
##################################################

function start_gnome_keyring() {

	export GNOME_KEYRING_CONTROL="/run/user/$(id --user)/keyring"

	if type gnome-keyring 1>/dev/null 2>&1 ;
	then

		writeLog "DEBUG" "GNOME keyring is installed"

		if ! pgrep --full gnome-keyring-daemon ;
		then

				writeLog "INFO" "Starting gnome-keyring-daemon"
				gnome-keyring-daemon \
					--start \
					--daemonize \
					--components=pkcs11,secrets,ssh || {
                        writeLog "ERROR" "Failed to start GNOME keyring daemon"
                        return 1
                    }

		else

				writeLog "INFO" "GNOME keyring daemon is already running"
				#writeLog "INFO" "Replacing gnome-keyring-daemon"
				#	gnome-keyring-daemon \
				#	--replace \
				#	--daemonize \
				#	--components=pkcs11,secrets,ssh || {
                #	    writeLog "ERROR" "Failed to replace GNOME keyring daemon"
                #	    return 1
                #	}

		fi

		LOCAL_KEYRING="${HOME}/.local/share/keyrings"
		if [[ ! -d "${LOCAL_KEYRING}" ]] ;
		then
			mkdir --parents "${LOCAL_KEYRING}" || {
				writeLog "ERROR" "Failed to create keyrings directory"
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

