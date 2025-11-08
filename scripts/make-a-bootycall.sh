#!/usr/bin/env bash

# Name: make-a-bootycall.sh
# Description: A script to de-unify UniFi Cloud Key Gen2 Plus, remove UniFi software, reclaim HDD, and install TFTP/PXE tools.
# Notes:
# 	- Inspired by community scripts and guides.
# 	- This script keeps the ck-ui package for the OLED display to remain functional.
# 	- After running, ports 80/443 should be free since Nginx and UniFi services are removed.
# 	- TFTP is setup and iPXE files served from the tftpboot dir which is mounted on the hard drive.
# 	- For custom OLED display: Uses imagemagick and ck-ui to create and display custom splash screens.

##################################################
# Initialization
##################################################

clear
set -euo pipefail

##################################################
# Variables
##################################################

BUCKET_LINK="https://link.storjshare.io/s/jwqhpvqz6kmmnxfwfgwrxialv5ia/junk"

# Temporary directory for downloads
TEMP_DIR="$(mktemp -d)"

##################################################
# Functions
##################################################

# Cleanup function
cleanup() {
	log "INFO" "Cleaning up..."
	rm -rf "$TEMP_DIR"
	log "INFO" "Cleanup complete."
}

# Logging function
log() {
	local level="$1"
	local msg="$2"
	local color
	case "$level" in
	DEBUG) color="\033[36m" ;; # Cyan
	INFO) color="\033[32m" ;;  # Green
	WARN) color="\033[33m" ;;  # Yellow
	ERR) color="\033[31m" ;;   # Red
	esac
	echo -e "${color}[${level}] ${msg}\033[0m"
}

# Function to check whoami
check_whoami() {
	if [[ $EUID -ne 0 ]]; then
		log "ERR" "This script must be run as root. Aborting."
		return 1
	fi
	log "INFO" "Running as root."
	return 0
}

# Function to check if running on UniFi Cloud Key Gen2
check_device() {
	if ! command -v ck-ui &>/dev/null || ! uname -a | grep -q "ui-qcom"; then
		log "ERR" "This script must run on a UniFi OS device with ck-ui installed. Aborting."
		return 1
	fi
	log "INFO" "Device check passed: Running on UniFi OS"
	return 0
}

# Function to download a file from a defined S3 Bucket.
download_file() {
	local http_params="download=1"
	local file=$1

	if [[ ${BUCKET_LINK:-EMPTY} == "EMPTY" ]]; then
		log "ERR" "No S3 Bucket link specified. Aborting."
		return 1
	fi

	if [[ ${file:-EMPTY} == "EMPTY" ]]; then
		log "ERR" "No file specified, nothing to download.. Aborting."
		return 1
	fi

	log "INFO" "Downloading file ${file}"
	curl \
		--silent \
		--location \
		--output "${TEMP_DIR}/${file}" \
		"${BUCKET_LINK}/${file}?${http_params}" ||
		{
			log "ERR" "Failed to download file ${file}. Aborting."
			return 1
		}

	log "INFO" "File downloaded successfully."
}

# Function to set up SSH with user's public key
setup_ssh() {
	log "INFO" "Setting up SSH for root access."
	read -rp "Paste your SSH public key (id_rsa.pub or id_ed25519.pub contents) and press Enter: " authorizedkey
	authorizedkey=$(echo "$authorizedkey" | xargs) # Trim whitespace
	if [[ -z $authorizedkey ]]; then
		log "ERR" "No key provided. Aborting."
		return 1
	fi
	if ! [[ $authorizedkey =~ ^(ssh-(rsa|dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ed25519)|ecdsa-sha2-nistp) ]]; then
		log "ERR" "Invalid key format. Must be a valid SSH public key. Aborting."
		return 1
	fi
	mkdir -p /root/.ssh
	echo "$authorizedkey" >>/root/.ssh/authorized_keys
	chmod 700 /root/.ssh
	chmod 600 /root/.ssh/authorized_keys
	touch /etc/ssh/sshd_config.d/99-allow-keys.conf
	cat <<-EOF >/etc/ssh/sshd_config.d/99-allow-keys.conf
		AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
		PasswordAuthentication no
		PermitRootLogin yes
		PubkeyAuthentication yes
	EOF
	systemctl restart ssh || {
		log "ERR" "Failed to restart SSH service. Please check your SSH configuration."
		return 1
	}
	log "INFO" "SSH setup complete. Test SSH access before proceeding."
}

# Function to confirm warranty void
confirm() {
	log "WARN" "This script will remove UniFi software, void your warranty, lose all your data and finally, kick your cat."
	log "WARN" "You may proceed at your own risk."
	read -rp "Type 'I understand you will kick my cat' to continue: " CHECK
	if [[ ${CHECK:-EMPTY} != "I understand you will kick my cat" ]]; then
		log "INFO" "Confirmation not received. Exiting."
		exit 0
	fi
	log "INFO" "Confirmation received. Proceeding to kick cat."
}

# Function to stop UniFi services
stop_services() {
	local unifi_services=(
		unifi
		unifi-core
		ulp-go
		unifi-directory
		uos-agent
		nginx
		postgresql@14-main
		mongodb
		ck-ui
		uhwd
		usbd
		usd
		ustated
	)
	log "INFO" "Stopping UniFi services."
	for service in "${unifi_services[@]}"; do
		log "INFO" "Stopping $service"
		systemctl stop "$service" || {
			log "WARN" "Failed to stop $service, skipping..."
		}
		systemctl disable "$service" || {
			log "WARN" "Failed to disable $service, skipping..."
		}
	done

	# Edge case: Don't disable/stop ck-ui to keep OLED functional
	systemctl enable --now ck-ui || true
}

# Function to uninstall UniFi packages
uninstall_packages() {
	local unifi_packages=(
		unifi
		unifi-core
		unifi-directory
		ulp-go
		uos-agent
		uos
		mongodb-org*
		postgresql*
		nginx*
		node*
		openjdk*
		simple-pid
		ui-snmp
		unifi-assets-uckp
		unifi-email-templates-all
		unifi-identity-update
		ubnt*
		ustd
		ustated
		usd
		usbd
		uhwd
		uid-agent
	)
	log "INFO" "Updating package list."
	apt update -y || {
		log "ERR" "Failed to update package list, aborting!"
		return 1
	}

	log "INFO" "Uninstalling UniFi and related packages."
	apt remove --purge -y "${unifi_packages[@]}" || {
		log "ERR" "Failed to uninstall UniFi packages, aborting!"
		return 1
	}

	apt autoremove --purge -y || {
		log "ERR" "Failed to autoremove packages, aborting!"
		return 1
	}

	apt clean || {
		log "ERR" "Failed to clean package cache, aborting!"
		return 1
	}
}

# Function to remove residual files and configs
remove_files() {
	local unifi_paths=(
		/usr/lib/unifi*
		/etc/unifi*
		/var/lib/unifi*
		/data/unifi*
		/etc/init.d/unifi*
		/usr/lib/ulp-go
		/var/lib/mongodb
		/data/postgresql
		/etc/nginx
		/var/www/html
		/var/log/nginx
		/persistent/system.cfg
	)
	log "INFO" "Removing residual UniFi files and configs."
	for unifi_path in "${unifi_paths[@]}"; do
		log "INFO" "Removing path ${unifi_path}"
		rm -rf "${unifi_path}" || {
			log "WARN" "Failed to remove ${unifi_path}, skipping..."
		}
	done
}

# Function to reclaim HDD space
reclaim_hdd() {
	local unifi_paths=(
		/volume1
	)
	local unifi_raid=(
		md3
	)
	local unifi_disks=(
		sda
	)

	log "INFO" "Processing mount points by path..."
	for path in "${unifi_paths[@]}"; do
		log "INFO" "Unmounting path ${path} all partitions"
		umount "${path}" || true
	done

	log "INFO" "Stopping mdadm RAID"
	for raid in "${unifi_raid[@]}"; do
		mdadm --stop "/dev/${raid}" || true
	done

	log "INFO" "Processing disks..."
	for disk in "${unifi_disks[@]}"; do
		log "INFO" "Unmounting all partitions on ${disk}"
		umount "/dev/${disk}*" || true
	done

	if ! lsblk -no NAME | grep -q '^sda5$'; then
		log "ERR" "Partition /dev/sda5 not found. Aborting HDD reclaim."
		return 1
	fi
	read -rp "Confirm formatting /dev/sda5 (all data will be lost)? [y/N] " confirm_format
	if [[ ${confirm_format,,} != "y" ]]; then
		log "INFO" "Formatting skipped."
		return 1
	fi
	umount /volume1 || true
	mdadm --stop /dev/md3 || true # Stop RAID if active
	if ! lsblk -no NAME | grep -q '^sda5$'; then
		log "ERR" "Partition /dev/sda5 not found. Aborting HDD reclaim."
		return 1
	fi
	read -rp "Confirm formatting /dev/sda5 (all data will be lost)? [y/N] " confirm_format
	if [[ ${confirm_format,,} != "y" ]]; then
		log "INFO" "Formatting skipped."
		return 1
	fi
	mkfs.ext4 -F /dev/sda5 # Format the main data partition
	mkdir -p /mnt/hdd
	mount /dev/sda5 /mnt/hdd
	echo "/dev/sda5 /mnt/hdd ext4 defaults 0 2" >>/etc/fstab
	log "INFO" "HDD reclaimed and mounted at /mnt/hdd. Use this for data storage."
}

# Function to install TFTP/PXE tools
install_tools() {
	local tools=(
		tftpd-hpa
	)

	log "INFO" "Installing TFTP/PXE/iPXE server tools."
	apt install -y "${tools[@]}" || {
		log "ERR" "Failed to install TFTP/PXE/iPXE server tools."
		return 1
	}

	log "INFO" "Tools installed."
}

# Function to configure TFTP/PXE tools.
configure_tools() {

	local TFTP_BOOT_DIR="/mnt/hdd/tftpboot"
	local TFTP_CONFIG="/etc/default/tftpd-hpa"
	local TFTP_SERVICE="tftp-hpa"
	local TFTP_USER="tftp"

	#########################
	# tftp-ha
	#########################

	log "INFO" "Configuring tftp-hpa"
	mkdir -p "${TFTP_BOOT_DIR}" || {
		log "ERR" "Failed to create tftpboot directory."
		return 1
	}
	chown -R "${TFTP_USER}:${TFTP_USER}" "${TFTP_BOOT_DIR}"
	cat <<-EOF >"${TFTP_CONFIG}"
		TFTP_USERNAME="${TFTP_USER}"
		TFTP_DIRECTORY="${TFTP_BOOT_DIR}"
		TFTP_ADDRESS=:69
		TFTP_OPTIONS="--listen --secure --verbose --timeout 900"
	EOF
	systemctl restart "${TFTP_SERVICE}" || {
		log "ERR" "Failed to restart ${TFTP_SERVICE} after configuration changes, verify the configuration file at ${TFTP_CONFIG}."
		return 1
	}

	#########################
	# iPXE
	#########################

	# Download the required files into the tftp root dir.
	PXE_FILES=(
		autoexec.ipxe
		config.ipxe
		ipxe.efi
		netboot.ipxe
		README.md
		threefold.ipxe
	)
	for file in "${PXE_FILES[@]}"; do
		# Download the file from the s3 bucket into the temp dir.
		download_file "${file}" || {
			log "ERR" "Failed to download required file ${file}"
			return 1
		}
		# Move the file to the tftp root directory.
		mv "${TEMP_DIR}/${file}" "${TFTP_BOOT_DIR}/${file}" || {
			log "ERR" "Failed to move ${file} to ${TFTP_BOOT_DIR}"
			return 1
		}
	done

	# Recursively set permissions on tftp boot directory.
	chown -R "${TFTP_USER}:${TFTP_USER}" "${TFTP_BOOT_DIR}" || {
		log "ERR" "Failed to set ownership on ${TFTP_BOOT_DIR}"
		return 1
	}
	chmod -R 0755 "${TFTP_BOOT_DIR}" || {
		log "ERR" "Failed to set permissions on ${TFTP_BOOT_DIR}"
		return 1
	}
	# If there is a scripts dir, set the exec bit.
	if [ -d "${TFTP_BOOT_DIR}/scripts" ]; then
		chmod -R +x "${TFTP_BOOT_DIR}/scripts" || {
			log "ERR" "Failed to set executable permissions on ${TFTP_BOOT_DIR}/scripts"
			return 1
		}
	fi

}

# Function to set up systemd service and timer for OLED stats display
set_custom_display() {
	local DISPLAY_DEPS=(
		imagemagick
	)
	log "INFO" "Setting up systemd service and timer for OLED stats display."

	apt install -y "${DISPLAY_DEPS[@]}" || {
		log "ERR" "Failed to install dependencies for OLED stats display"
		return 1
	}

	# Keep ck-ui running for display to work.
	systemctl enable ck-ui || true
	systemctl start ck-ui || true

	# Create the stats script
	cat <<-'EOF' >/usr/local/bin/oled-stats.sh
		#!/usr/bin/env bash
		HOST=$(hostname)
		TEMP=$(cat /sys/class/thermal/thermal_zone18/temp | awk '{printf "%.1f°C", $1/1000}')
		convert -size 160x60 -background black -fill white -pointsize 12 -gravity center label:"$HOST\nTemp: $TEMP" /tmp/oled.png
		ck-splash -f /tmp/oled.png
	EOF
	chmod +x /usr/local/bin/oled-stats.sh

	# Create a systemd service to run the stats script.
	cat <<-EOF >/etc/systemd/system/oled-stats.service
		[Unit]
		Description=OLED Dynamic Stats Display unit

		[Service]
		Type=oneshot
		ExecStart=/usr/local/bin/oled-stats.sh

		[Install]
		WantedBy=multi-user.target
	EOF

	# Create a systemd timer to run the stats script every minute.
	cat <<-'EOF' >/etc/systemd/system/oled-stats.timer
		[Unit]
		Description=OLED Dynamic Stats Display timer

		[Timer]
		OnBootSec=1min
		OnUnitActiveSec=1min

		[Install]
		WantedBy=timers.target
	EOF

	# Reload systemd, enable and start the timer
	systemctl daemon-reload
	systemctl enable oled-stats.timer || {
		log "ERR" "Failed to enable OLED stats timer."
		exit 1
	}
	systemctl start oled-stats.timer || {
		log "ERR" "Failed to start OLED stats timer."
		exit 1
	}

	log "INFO" "OLED stats service and timer set up and started."
}

# Main execution
main() {
	# Dependency checks
	command -v curl >/dev/null 2>&1 || {
		log "ERR" "curl not found."
		exit 1
	}
	command -v mdadm >/dev/null 2>&1 || {
		log "ERR" "mdadm not found."
		exit 1
	}
	command -v mkfs.ext4 >/dev/null 2>&1 || {
		log "ERR" "mkfs.ext4 not found."
		exit 1
	}
	command -v apt >/dev/null 2>&1 || {
		log "ERR" "apt not found."
		exit 1
	}
	command -v systemctl >/dev/null 2>&1 || {
		log "ERR" "systemctl not found."
		exit 1
	}
	command -v lsblk >/dev/null 2>&1 || {
		log "ERR" "lsblk not found."
		exit 1
	}

	trap cleanup EXIT

	log "INFO" "Starting de-unify process."
	check_device || {
		log "ERR" "Device check failed."
		exit 1
	}
	check_whoami || {
		log "ERR" "User check failed."
		exit 1
	}
	setup_ssh || {
		log "ERR" "SSH setup failed."
		exit 1
	}
	confirm || {
		log "ERR" "Confirmation failed."
		exit 1
	}
	stop_services || {
		log "ERR" "Failed to stop services."
		exit 1
	}
	uninstall_packages || {
		log "ERR" "Failed to uninstall packages."
		exit 1
	}
	remove_files || {
		log "ERR" "Failed to remove files."
		exit 1
	}
	reclaim_hdd || {
		log "ERR" "Failed to reclaim HDD."
		exit 1
	}
	install_tools || {
		log "ERR" "Failed to install tools."
		exit 1
	}
	configure_tools || {
		log "ERR" "Failed to configure tools."
		exit 1
	}
	set_custom_display || {
		log "ERR" "Failed to set custom display."
		exit 1
	}
	log "INFO" "De-unify complete. Rebooting in 5 seconds."
	sleep 5
	reboot
}

##################################################
# Main
##################################################

main
