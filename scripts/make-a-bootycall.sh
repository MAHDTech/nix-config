#!/usr/bin/env bash

# Name: make-a-bootycall.sh
# Description:
# 	A script to de-unify UniFi Cloud Key Gen2 Plus, remove UniFi software, reclaim HDD, and install TFTP/PXE tools.
#   This prepares the system to run 'BootyCall' a TFTP/iPXE server that always answers the call to boot your devices.
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

BUCKET_LINK="https://link.storjshare.io/raw/jwqhpvqz6kmmnxfwfgwrxialv5ia/junk"

# Temporary directory for downloads
TEMP_DIR="$(mktemp -d)"

##################################################
# Functions
##################################################

function yolo() {
	cat <<-'EOF'
		___  ___  ______    ___        ______    ___
		|"  \/"  |/    " \  |"  |      /    " \  |"  |
		 \   \  /// ____  \ ||  |     // ____  \ ||  |
		  \\  \//  /    ) :)|:  |    /  /    ) :)|:  |
		  /   /(: (____/ //  \  |___(: (____/ //_|  /
		 /   /  \        /  ( \_|:  \\        // |_/ )
		|___/    \"_____/    \_______)\"_____/(_____/

	EOF
	return 0
}

function configure_motd() {

	cat <<-EOF >>/etc/motd-messages
		Always answering the boot(y) call – Ready for your late-night PXE request!
		Answering the call: BootyCall, your PXE partner in crime.
		BootyCall activated: Get your rear in gear for network booting!
		BootyCall – Because every server needs a cheeky start.
		BootyCall: Cracking up your network – One boot at a time!
		BootyCall: Serving up bootstraps since [date] – Don't be a bum, log in!
		BootyCall: The bottom line in bootstrapping – Always up!
		Shake it and boot: BootyCall here for your iPXE emergencies.
	EOF

	cat <<-EOF >/usr/local/bin/motd-rotator
		#!/usr/bin/env bash

		MOTD_MESSAGES=/etc/motd-messages

		# Step 1. Read a random message from the list of messages.
		random_message=\$(shuf -n 1 /etc/motd-messages)

		# Step 2. Layout the base MOTD file.
		cat <<-"MOTD_EOF" > /etc/motd
			  ___           _         ___      _ _
			 | _ ) ___  ___| |_ _  _ / __|__ _| | |
			 | _ \/ _ \/ _ \  _| || | (__/ _\` | | |
			 |___/\___/\___/\__|\_, |\___\__,_|_|_|
			                    |__/
		MOTD_EOF

		# Step 3. Append the random message to the MOTD file.
		cat <<-MOTD_EOF >> /etc/motd
			\${random_message}
		MOTD_EOF
		exit 0
	EOF

	chmod +x /usr/local/bin/motd-rotator

	# Create a systemd unit that rotates the message daily
	cat <<-EOF >/etc/systemd/system/motd-rotator.service
		[Unit]
		Description=MOTD rotator unit

		[Service]
		Type=oneshot
		ExecStart=/usr/local/bin/motd-rotator

		[Install]
		WantedBy=multi-user.target
	EOF

	# Create a systemd timer for daily rotation
	cat <<-EOF >/etc/systemd/system/motd-rotator.timer
		[Unit]
		Description=MOTD rotator timer

		[Timer]
		OnCalendar=daily
		Persistent=true

		[Install]
		WantedBy=timers.target
	EOF

	# Reload systemd daemon
	systemctl daemon-reload

	# Enable and start the timer
	systemctl enable --now motd-rotator.service motd-rotator.timer

}

# Cleanup function
function cleanup() {
	log "INFO" "Cleaning up..."
	rm -rf "$TEMP_DIR"
	log "INFO" "Cleanup complete."
}

function print_header() {
	echo -e "\033[34m##################################################\033[0m"
}

function print_footer() {
	echo -e "\033[34m##################################################\033[0m"
}

# Logging function
function log() {
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
function check_whoami() {
	if [[ $EUID -ne 0 ]]; then
		log "ERR" "This script must be run as root. Aborting."
		return 1
	fi
	log "INFO" "Running as root."
	return 0
}

# Function to check if running on UniFi Cloud Key Gen2
function check_device() {
	if ! command -v ck-ui &>/dev/null || ! uname -a | grep -q "ui-qcom"; then
		log "ERR" "This script must run on a UniFi OS device with ck-ui installed. Aborting."
		return 1
	fi
	log "INFO" "Device check passed: Running on UniFi OS"
	return 0
}

# Function to download a file from a defined S3 Bucket.
download_file() {
	local folder=$1
	local file=$2

	if [[ ${BUCKET_LINK:-EMPTY} == "EMPTY" ]]; then
		log "ERR" "No S3 Bucket link specified. Aborting."
		return 1
	fi

	if [[ ${folder:-EMPTY} == "EMPTY" ]]; then
		log "ERR" "No folder was specified, please pass the folder and file. Aborting."
		return 1
	fi

	if [[ ${file:-EMPTY} == "EMPTY" ]]; then
		log "ERR" "No file was specified, nothing to download.. Aborting."
		return 1
	fi

	# Create the directory structure inside the temp directory
	mkdir -p "${TEMP_DIR}/${folder}" || {
		log "ERR" "Failed to create directory ${TEMP_DIR}/${folder}. Aborting."
		return 1
	}

	log "INFO" "Downloading file ${file} into ${TEMP_DIR}/${folder}"
	curl \
		--silent \
		--location \
		--output "${TEMP_DIR}/${folder}/${file}" \
		"${BUCKET_LINK}/${folder}/${file}" ||
		{
			log "ERR" "Failed to download file ${file} from the folder ${folder} in the s3 bucket ${BUCKET_LINK}. Aborting."
			return 1
		}

	log "INFO" "File downloaded successfully."
}

# Function to set up SSH with user's public key
function setup_ssh() {
	log "INFO" "Setting up SSH for root access."
	print_header
	read -rp "Paste your SSH public key (id_rsa.pub or id_ed25519.pub contents) and press Enter: " authorizedkey
	print_footer
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
	if [ ! -f /root/.ssh/authorized_keys ] || ! grep -q "$authorizedkey" /root/.ssh/authorized_keys; then
		echo "$authorizedkey" >>/root/.ssh/authorized_keys
	else
		log "INFO" "SSH public key already present in authorized_keys."
	fi
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
function confirm() {
	log "WARN" "This script will remove UniFi software, void your warranty, lose all your data and finally, kick your cat."
	log "WARN" "You may proceed at your own risk."
	print_header
	read -rp "Type 'I understand you will kick my cat' to continue: " CHECK
	print_footer
	if [[ ${CHECK:-EMPTY} != "I understand you will kick my cat" ]]; then
		log "INFO" "Confirmation not received. Exiting."
		exit 0
	fi
	log "INFO" "Confirmation received. Proceeding to kick cat."
}

# Function to stop UniFi services
function stop_services() {
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
function uninstall_packages() {
	local unifi_packages=(
		mongodb-clients
		mongodb-server
		mongodb-server-core
		nginx*
		node*
		openjdk*
		postgresql*
		simple-pid
		ubnt-unifi-setup
		ucore-setup-lisenter
		ui-snmp
		unifi-assets-uckp
		unifi-core
		unifi-directory
		unifi-email-templates-all
		unifi-identity-update
		ustate-exporter
		ustd
	)
	log "INFO" "Updating package list."
	apt update -y || {
		log "ERR" "Failed to update package list, aborting!"
		return 1
	}

	log "INFO" "Fixing any broken packages before removal."
	apt --fix-broken install -y || {
		log "ERR" "Failed to fix broken packages."
		return 1
	}

	# HACK: Manually remove broken PostgreSQL packages
	log "INFO" "Temporarily disabling PostgreSQL prerm scripts to bypass removal errors."
	for pg_version in 14 16; do
		prerm_file="/var/lib/dpkg/info/postgresql-${pg_version}.prerm"
		if [ -f "$prerm_file" ]; then
			mv "$prerm_file" "${prerm_file}.disabled" 2>/dev/null || true
		fi
	done

	log "INFO" "Uninstalling UniFi and related packages."
	for package in "${unifi_packages[@]}"; do
		if dpkg -s "$package" >/dev/null 2>&1; then
			log "INFO" "Removing $package"
			apt remove --purge -y "$package" || log "WARN" "Failed to remove $package, proceeding."
		else
			log "INFO" "$package is not installed, skipping."
		fi
	done

	apt autoremove --purge -y || log "WARN" "Failed to autoremove packages, proceeding."
	apt clean || log "WARN" "Failed to clean package cache, proceeding."
}

# Function to remove residual files and configs
function remove_files() {
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
		/srv
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
function reclaim_hdd() {
	local unifi_paths=(
		/volume1
	)
	local unifi_raid=(
		md3
	)
	local unifi_disks=(
		sda
	)

	# Check if already reclaimed
	if mountpoint -q /mnt/hdd; then
		log "INFO" "HDD already reclaimed and mounted at /mnt/hdd."
		return 0
	fi

	log "INFO" "Processing mount points by path..."
	for path in "${unifi_paths[@]}"; do
		log "INFO" "Unmounting path ${path} all partitions"
		umount "${path}" 2>/dev/null || true
	done

	log "INFO" "Stopping mdadm RAID"
	for raid in "${unifi_raid[@]}"; do
		if [ -b "/dev/${raid}" ]; then
			mdadm --stop "/dev/${raid}" 2>/dev/null || true
		fi
	done

	log "INFO" "Processing disks..."

	for disk in "${unifi_disks[@]}"; do
		log "INFO" "Unmounting all partitions on ${disk}"
		umount "/dev/${disk}*" 2>/dev/null || true
	done

	print_header
	read -rp "Confirm formatting /dev/sda5 (all data will be lost)? [y/N] " confirm_format
	print_footer
	if [[ ${confirm_format:-EMPTY} != [yY] ]]; then
		log "INFO" "Formatting skipped."
		return 1
	fi

	log "INFO" "Formatting /dev/sda5"
	mkfs.ext4 -F /dev/sda5 || {
		log "ERR" "Failed to format /dev/sda5."
		return 1
	}

	log "INFO" "Creating /mnt/hdd"
	mkdir -p /mnt/hdd || {
		log "ERR" "Failed to create /mnt/hdd."
		return 1
	}

	log "INFO" "Mounting /dev/sda5 to /mnt/hdd"
	mount /dev/sda5 /mnt/hdd || {
		log "ERR" "Failed to mount /dev/sda5."
		return 1
	}

	log "INFO" "HDD reclaimed and mounted at /mnt/hdd. Note: Mount manually after reboot with 'mount /dev/sda5 /mnt/hdd' since /etc/fstab changes don't persist on overlayfs."
}

# Function to install TFTP/PXE tools
function install_tools() {
	local tools=(
		tftp
		tftpd-hpa
		pxelinux
	)

	log "INFO" "Installing TFTP/PXE/iPXE server tools."
	apt install -y "${tools[@]}" || {
		log "ERR" "Failed to install TFTP/PXE/iPXE server tools."
		return 1
	}

	log "INFO" "Tools installed."
}

# Function to configure TFTP/PXE tools.
function configure_tools() {

	local TFTP_BOOT_DIR="/mnt/hdd/tftpboot"
	local TFTP_CONFIG="/etc/default/tftpd-hpa"
	local TFTP_SERVICE="tftpd-hpa"
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
		TFTP_ADDRESS=":69"
		TFTP_OPTIONS="--listen --secure --verbose --timeout 900"
	EOF

	# Create persistent systemd mount unit for /mnt/hdd
	log "INFO" "Creating systemd mount unit for persistent HDD mount."
	cat <<-EOF >/etc/systemd/system/mnt-hdd.mount
		[Unit]
		Description=Mount HDD at /mnt/hdd

		[Mount]
		What=/dev/sda5
		Where=/mnt/hdd
		Type=ext4
		Options=defaults

		[Install]
		WantedBy=multi-user.target
	EOF
	systemctl enable mnt-hdd.mount || log "WARN" "Failed to enable mnt-hdd.mount, mount may not persist."

	# Add dependency for tftpd-hpa to start after mount
	mkdir -p /etc/systemd/system/tftpd-hpa.service.d
	cat <<-EOF >/etc/systemd/system/tftpd-hpa.service.d/10-mount.conf
		[Unit]
		Requires=mnt-hdd.mount
		After=mnt-hdd.mount
	EOF

	systemctl restart "${TFTP_SERVICE}" || {
		log "ERROR" "Failed to restart ${TFTP_SERVICE} after configuration changes, verify the configuration file at ${TFTP_CONFIG}."
		return 1
	}

	#########################
	# iPXE
	#########################

	# Download the required files into the tftp root dir.
	TFTP_FILES=(
		autoexec.ipxe
		config.ipxe
		ipxe.efi
		netboot.ipxe
		README.md
		threefold.ipxe
	)
	for file in "${TFTP_FILES[@]}"; do
		# Download the file from the s3 bucket into the temp dir.
		download_file "tftp" "${file}" || {
			log "ERR" "Failed to download required file ${file} from the tftp dir in the s3 bucket."
			return 1
		}
		# Move the file to the tftp root directory.
		mv "${TEMP_DIR}/tftp/${file}" "${TFTP_BOOT_DIR}/${file}" || {
			log "ERR" "Failed to move ${file} to ${TFTP_BOOT_DIR}"
			return 1
		}
	done

	# Recursively set permissions on tftp boot directory.
	chown -R "${TFTP_USER}:${TFTP_USER}" "${TFTP_BOOT_DIR}" || {
		log "ERR" "Failed to set ownership on ${TFTP_BOOT_DIR}"
		return 1
	}
	chmod -R 0660 "${TFTP_BOOT_DIR}" || {
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
function set_custom_display() {
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

# Function to enable unattended updates
function enable_unattended_updates() {
	local DEB_DEPS=(
		unattended-upgrades
	)

	apt update || {
		log "ERR" "Failed to update package lists."
		exit 1
	}
	apt install -y "${DEB_DEPS[@]}" || {
		log "ERR" "Failed to install unattended-upgrades."
		exit 1
	}

	log "INFO" "Configuring auto-upgrades"

	cat <<-EOF >/etc/apt/apt.conf.d/20auto-upgrades
		APT::Periodic::Update-Package-Lists "1";
		APT::Periodic::Unattended-Upgrade "1";
	EOF

	log "INFO" "Configuring unattended-upgrades"

	cat <<-EOF >/etc/apt/apt.conf.d/50unattended-upgrades
		Unattended-Upgrade::Allowed-Origins {
		    "\${distro_id}:\${distro_codename}";
		    "\${distro_id}:\${distro_codename}-security";
		    "\${distro_id}:\${distro_codename}-updates";
		};
		Unattended-Upgrade::AutoFixInterruptedDpkg "true";
		Unattended-Upgrade::MinimalSteps "true";
		Unattended-Upgrade::InstallOnShutdown "false";
		Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
		Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
		Unattended-Upgrade::Remove-Unused-Dependencies "true";
		Unattended-Upgrade::Automatic-Reboot "true";
		Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
		Unattended-Upgrade::Automatic-Reboot-Time "02:00";
		Unattended-Upgrade::OnlyOnACPower "true";
		Unattended-Upgrade::Allow-downgrade "false";
		Unattended-Upgrade::Allow-APT-Mark-Fallback "true";
	EOF

	log "INFO" "Unattended upgrades enabled."
}

function finish_up() {
	print_header
	read -rp "The 'de-unifi-cation' process is complete. Are you ready to reboot? [y/N] " response
	print_footer
	if [[ ${response:-EMPTY} == [yY] ]]; then
		yolo || true
		reboot
	fi
	log "INFO" "Skipping reboot"
}

# Main execution
function main() {
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
	enable_unattended_updates || {
		log "ERR" "Failed to enable unattended updates."
		exit 1
	}
	configure_motd || {
		log "ERR" "Failed to configure MOTD."
		exit 1
	}
	finish_up || {
		log "ERR" "Failed to finish up."
		exit 1
	}
}

##################################################
# Main
##################################################

main
