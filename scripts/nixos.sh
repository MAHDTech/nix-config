#!/usr/bin/env bash

#########################
# Name: nixos.sh
# Description: Configures a NixOS install on a single or mirrored ZFS drive.
# Reference: https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html
#########################

##########
# Variables
##########

export NIXPKGS_ALLOW_UNFREE=1

SCRIPT=${0##*/}
SCRIPT_DIR=${0%/*}

# The HDDs where NixOS will be installed.
INST_DISKS=(
	"${NIX_CONFIG_INST_DISK_1:-}"
	"${NIX_CONFIG_INST_DISK_2:-}"
)

# The size of the UEFI System Partition in MB
INST_PARTSIZE_UESP="${NIX_CONFIG_INST_PARTSIZE_UESP:=1024}"

# The size of the boot partition in GB
INST_PARTSIZE_BOOT="${NIX_CONFIG_INST_PARTSIZE_BOOT:=4}"

# The size of the root pool in GB. If set to '0' will use all remaining space.
INST_PARTSIZE_ROOT="${NIX_CONFIG_INST_PARTSIZE_ROOT:=0}"

# The size of the swap parition in GB.
INST_PARTSIZE_SWAP="${NIX_CONFIG_INST_PARTSIZE_SWAP:=64}"

# Whether to use swap or not.
INST_ENABLE_SWAP="${NIX_CONFIG_INST_ENABLE_SWAP:=TRUE}"

# Whether to enable encryption or not.
INST_ENABLE_ENCRYPTION="${NIX_CONFIG_INST_ENABLE_ENCRYPTION:=TRUE}"

# Whether to enable impermanence or not.
INST_ENABLE_IMPERMANENCE="${NIX_CONFIG_INST_ENABLE_IMPERMANENCE:=FALSE}"

# The name of the ZFS boot pool
INST_ZFS_POOL_BOOT="bpool"

# The name of the ZFS boot pool
INST_ZFS_POOL_ROOT="rpool"

# The hostname of the system
INST_HOSTNAME="${NIX_CONFIG_INST_HOSTNAME}"

##########
# Functions
##########

if [[ -f "${SCRIPT_DIR}/common.sh" ]];
then
	# shellcheck source=scripts/common.sh
	source "${SCRIPT_DIR}/common.sh"
else
	echo "Unable to import common functions from ${SCRIPT_DIR}"
	exit 1
fi

# Partition shennanigans.

if [[ "${NIX_CONFIG_INST_DISK_1}" =~ ^/dev/nvme* ]];
then

	writeLog "INFO" "nvme, add 'p' to partition names."

	PART_1="p1"
	PART_2="p2"
	PART_3="p3"
	PART_4="p4"

elif [[ "${NIX_CONFIG_INST_DISK_1}" =~ /dev/sd* ]];
then

	writeLog "INFO" "sdX, removing 'p' from partition names."

	PART_1="1"
	PART_2="2"
	PART_3="3"
	PART_4="4"

else

	writeLog "WARN" "Untested disk type, assuming default partition names."
	
	PART_1="1"
	PART_2="2"
	PART_3="3"
	PART_4="4"

fi

##########
# Main
##########

writeLog "DEBUG" "Started ${SCRIPT}"

# Re-run this script as root if required.
if [[ "${EUID}" -ne 0 ]];
then
	writeLog "INFO" "Elevating script to root user."
	exec sudo -E -s "$0" "$@"
else
	writeLog "INFO" "Executing script as root user."
fi

# Ensure the hostname is not empty before starting.
if [[ "${INST_HOSTNAME:-EMPTY}" == "EMPTY" ]];
then
	writeLog "ERROR" "The hostname cannot be empty"
	exit 1
fi

PROMPT="This will now wipe all partitions on the following disks: ${INST_DISKS[*]}. Are you sure? Y/N: "
read -p "${PROMPT}" -n 1 -r CHOICE
echo -e "\n"

if [[ ! "${CHOICE}" =~ ^[Yy] ]];
then
	writeLog "DEBUG" "User enter N at prompt."
	echo "No changes have been made, goodbye!"
	exit 0
fi

writeLog "INFO" "Preparing disks"

umount -Rl /mnt 2>/dev/null || true
zpool export -a || true

WIPED_DISKS=0
for DISK in "${INST_DISKS[@]}";
do

	if [[ "${#DISK}" -lt 3 ]];
	then
		writeLog "DEBUG" "Skipping incorrect disk variable"
		continue
	elif [[ "${DISK:-EMPTY}" == "EMPTY" ]];
	then
		writeLog "DEBUG" "Skipping empty disk variable"
		continue
	# Make sure there is a block device at the provided location.
	elif [[ ! -b "${DISK}" ]];
	then
		writeLog "ERROR" "${DISK:-NONE} is not a valid block device!"
		exit 2
	fi

	writeLog "INFO" "Wiping disk ${DISK}"

	zpool labelclear -f "${DISK}" || true

	wipefs -a "${DISK}" || {
		writeLog "ERROR" "Failed to wipe filesystem on ${DISK}"
		exit 99
	}

	sgdisk --zap-all "${DISK}" || {
		writeLog "ERROR" "Failed to wipe all partitions on ${DISK}"
		exit 99
	}

	writeLog "INFO" "Creating UEFI system parition"
	sgdisk -n 1:1M:+${INST_PARTSIZE_UESP}M -t 1:EF00 "${DISK}" || {
		writeLog "ERROR" "Failed to create UEFI system partition!"
		exit 98
	}

	writeLog "INFO" "Creating boot partition"
	sgdisk -n 2:0:+${INST_PARTSIZE_BOOT}G -t 2:BE00 "${DISK}" || {
		writeLog "ERROR" "Failed to create boot partition!"
		exit 97
	}

	if [[ "${INST_ENABLE_SWAP^^}" == "TRUE" ]];
	then
		writeLog "INFO" "Creating SWAP partition"
		sgdisk -n 4:0:+${INST_PARTSIZE_SWAP}G -t 4:8200 "${DISK}" || {
			writeLog "ERROR" "Failed to create SWAP partition!"
			exit 96
		}
	fi

	writeLog "INFO" "Creating root partition"
	sgdisk -n 3:0:+${INST_PARTSIZE_ROOT}G -t 3:BF00 "${DISK}" || {
		writeLog "ERROR" "Failed to create root partition!"
		exit 96
	}

	WIPED_DISKS=$((WIPED_DISKS + 1 ))
	writeLog "INFO" "Wiped ${WIPED_DISKS} disks"

done

writeLog "INFO" "Creating ZFS Pools"

if [[ "${WIPED_DISKS}" -eq 1 ]];
then

	writeLog "INFO"  "Creating ZFS pool (single) ${INST_ZFS_POOL_BOOT}"

	# shellcheck disable=SC2046
	zpool create -f \
		-o compatibility=grub2 \
		-o ashift=12 \
		-o autotrim=on \
		-O atime=off \
		-O acltype=posixacl \
		-O canmount=off \
		-O compression=lz4 \
		-O devices=off \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O mountpoint=/boot \
		-R /mnt \
		${INST_ZFS_POOL_BOOT} \
		"${NIX_CONFIG_INST_DISK_1:-}${PART_2}" || {
			writeLog "INFO"  "Failed to create single drive boot pool!"
			exit 95
		}

	writeLog "INFO"  "Creating ZFS pool (single) ${INST_ZFS_POOL_ROOT}"

	# shellcheck disable=SC2046
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		-O atime=off \
		-O acltype=posixacl \
		-O canmount=off \
		-O compression=zstd \
		-O dnodesize=auto \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O mountpoint=/ \
		-R /mnt \
		${INST_ZFS_POOL_ROOT} \
		"${NIX_CONFIG_INST_DISK_1:-}${PART_3}" || {
			writeLog "INFO"  "Failed to create single drive root pool!"
			exit 94
		}

elif [[ "${WIPED_DISKS}" -eq 2 ]];
then

	writeLog "INFO"  "Creating ZFS pool (mirror) ${INST_ZFS_POOL_BOOT}"

	# shellcheck disable=SC2046
	zpool create -f \
		-o compatibility=grub2 \
		-o ashift=12 \
		-o autotrim=on \
		-O atime=off \
		-O acltype=posixacl \
		-O canmount=off \
		-O compression=lz4 \
		-O devices=off \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O mountpoint=/boot \
		-R /mnt \
		${INST_ZFS_POOL_BOOT} \
		mirror \
		$(for DISK in "${INST_DISKS[@]}"; do echo -n "${DISK}${PART_2} " ; done ) || {
			writeLog "INFO"  "Failed to create mirrored drive boot pool!"
			exit 95
		}

	writeLog "INFO"  "Creating ZFS pool (mirror) ${INST_ZFS_POOL_ROOT}"

	# shellcheck disable=SC2046
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		-O atime=off \
		-O acltype=posixacl \
		-O canmount=off \
		-O compression=zstd \
		-O dnodesize=auto \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O mountpoint=/ \
		-R /mnt \
		${INST_ZFS_POOL_ROOT} \
		mirror \
		$(for DISK in "${INST_DISKS[@]}"; do echo -n "${DISK}${PART_3} " ; done ) || {
			writeLog "INFO"  "Failed to create mirrored drive boot pool!"
			exit 94
		}

else

	writeLog "ERROR" "Unsupported disk configuration, ${WIPED_DISKS} disks has not been tested."

fi

writeLog "INFO" "Creating ZFS Datasets"
	
if [[ "${INST_ENABLE_ENCRYPTION^^}" == "TRUE" ]];
then

	writeLog "INFO" "Creating root nixos dataset with encryption enabled."
	writeLog "WARNING" "Encryption passphrase has a minimum length of 8 characters."

	zfs create \
		-o canmount=off \
		-o mountpoint=none \
 		-o encryption=on \
 		-o keylocation=prompt \
 		-o keyformat=passphrase \
 		${INST_ZFS_POOL_ROOT}/nixos || {
			writeLog "ERROR" "Failed to create nixos ZFS dataset on ${INST_ZFS_POOL_ROOT} pool"
			exit 93
		}

else

	writeLog "INFO" "Creating root nixos dataset with encryption disabled."

	zfs create \
		-o canmount=off \
		-o mountpoint=none \
 		${INST_ZFS_POOL_ROOT}/nixos || {
			writeLog "ERROR" "Failed to create nixos ZFS dataset on ${INST_ZFS_POOL_ROOT} pool"
			exit 93
		}

fi

writeLog "INFO" "Creating system datasets"

zfs create \
	-o canmount=on \
	-o mountpoint=/ \
	${INST_ZFS_POOL_ROOT}/nixos/root || {
		writeLog "ERROR" "Failed to create system dataset root"
		exit 92
	}

zfs create \
	-o canmount=on \
	-o mountpoint=/nix \
	${INST_ZFS_POOL_ROOT}/nixos/nix || {
		writeLog "ERROR" "Failed to create system dataset nix"
		exit 92
	}	

zfs create \
	-o canmount=on \
	-o mountpoint=/home \
	${INST_ZFS_POOL_ROOT}/nixos/home || {
		writeLog "ERROR" "Failed to create system dataset home"
		exit 92
	}

zfs create \
	-o canmount=off \
	-o mountpoint=/var \
	${INST_ZFS_POOL_ROOT}/nixos/var || {
		writeLog "ERROR" "Failed to create system dataset var"
		exit 92
	}

zfs create \
	-o canmount=on \
	${INST_ZFS_POOL_ROOT}/nixos/var/lib || {
		writeLog "ERROR" "Failed to create system dataset lib"
		exit 92
	}

zfs create \
	-o canmount=on \
	${INST_ZFS_POOL_ROOT}/nixos/var/log || {
		writeLog "ERROR" "Failed to create system dataset log"
		exit 92
	}

zfs create \
	-o canmount=off \
	-o refreservation=10G \
	-o mountpoint=none \
	${INST_ZFS_POOL_ROOT}/reserved || {
		writeLog "ERROR" "Failed to create system dataset reserved"
		exit 92
	}

writeLog "INFO" "Creating boot datasets"

zfs create \
	-o canmount=off \
	-o mountpoint=none \
	${INST_ZFS_POOL_BOOT}/nixos || {
		writeLog "ERROR" "Failed to create boot dataset nixos"
		exit 91
	}

zfs create \
	-o canmount=on \
	-o mountpoint=/boot \
	${INST_ZFS_POOL_BOOT}/nixos/boot || {
		writeLog "ERROR" "Failed to create boot dataset nixos"
		exit 91
	}

writeLog "INFO" "Formatting and mouting EFI System Partition"

for DISK in "${INST_DISKS[@]}";
do

	if [[ "${#DISK}" -lt 3 ]];
	then
		writeLog "DEBUG" "Skipping incorrect length disk variable"
		continue
	elif [[ "${DISK:-EMPTY}" == "EMPTY" ]];
	then
		writeLog "DEBUG" "Skipping empty disk variable"
		continue
	# Make sure there is a block device at the provided location.
	elif [[ ! -b "${DISK}" ]];
	then
		writeLog "ERROR" "${DISK:-NONE} is not a valid block device!"
		exit 2
	else
		mkfs.vfat -n EFI "${DISK}${PART_1}" || {
			writeLog "ERROR" "Failed to create EFI FAT partition"
			exit 90
		}
	fi

done

if [[ "${WIPED_DISKS}" -eq 2 ]];
then

	writeLog "INFO" "Configuring EFI for mirrored disks"

	for DISK in "${INST_DISKS[@]}";
	do

		if [[ "${#DISK}" -lt 3 ]];
		then
			writeLog "DEBUG" "Skipping incorrect length disk variable"
			continue
		elif [[ "${DISK:-EMPTY}" == "EMPTY" ]];
		then
			writeLog "DEBUG" "Skipping empty disk variable"
			continue
		# Make sure there is a block device at the provided location.
		elif [[ ! -b "${DISK}" ]];
		then
			writeLog "ERROR" "${DISK:-NONE} is not a valid block device!"
			exit 2
		else
			mkdir --parents "/mnt/boot/efis/${DISK##*/}${PART_1}" || {
				writeLog "ERROR" "Failed to create required directory for EFI FAT partitions"
				exit 90
			}
			mount -t vfat ${DISK}${PART_1} "/mnt/boot/efis/${DISK##*/}${PART_1}" || {
				writeLog "ERROR" "Failed to mount EFI FAT partition"
				exit 90
			}
		fi

	done

fi

mkdir --parents /mnt/boot/efi || {
	writeLog "ERROR" "Failed to create required directory for EFI"
	exit 90
}

mount -t vfat "$(echo "${INST_DISKS[@]}" | cut -f1 -d\ )${PART_1}" /mnt/boot/efi || {
	writeLog "ERROR" "Failed to mount EFI partition"
	exit 90
}

writeLog "INFO" "Disabling cache"

mkdir --parents /mnt/etc/zfs/ || {
	writeLog "ERROR" "Failed to create directory to disable cache"
	exit 89
}

rm -f /mnt/etc/zfs/zpool.cache || {
	writeLog "ERROR" "Failed to remove existing cache file"
	exit 89
}

touch /mnt/etc/zfs/zpool.cache || {
	writeLog "ERROR" "Failed to create new cache file"
	exit 89
}

chmod a-w /mnt/etc/zfs/zpool.cache || {
	writeLog "ERROR" "Failed to remove write permissions to cache file"
	exit 89
}

chattr +i /mnt/etc/zfs/zpool.cache || {
	writeLog "ERROR" "Failed to make cache file immutable"
	exit 89
}

writeLog "INFO" "Generating NixOS initial system configuration"

nixos-generate-config --root /mnt || {
	writeLog "ERROR" "Failed to generate NixOS initial system configuration"
	exit 88
}

#writeLog "INFO" "Hashing root password"
#INST_ROOT_PASSWD=$(mkpasswd -m SHA-512 -s)
#export INST_ROOT_PASSWD

if [[ "${INST_ENABLE_IMPERMANENCE^^}" == "TRUE" ]];
then

	writeLog "INFO" "Enabling impermanence on root file system."

	echo "TODO: Enable impermanence"
	echo "Refer to:"
	echo "https://nixos.wiki/wiki/Impermanence"
	echo "https://nixos.wiki/wiki/ZFS#Immutable_Root_on_ZFS"
	echo "https://github.com/voidzero/nixos-zfs-setup/blob/master/nixos-zfs-setup.sh"

fi

writeLog "INFO" "Displaying current ZFS pool information"
zpool status
echo -e "\n\n"

writeLog "INFO" "Displaying current ZFS dataset configuration"
zfs list
echo -e "\n\n"

# HACK: Fix this fragile.
INST_EFI_UUID=$(ls -la /dev/disk/by-uuid/ | grep "${NIX_CONFIG_INST_DISK_1##*/}${PART_1}" | cut -d ' ' -f 10)

writeLog "WARN" "The UUID for the EFI partition has changed, update git with the id ${INST_EFI_UUID:-ERROR} before continuing..." 

ls -la /dev/disk/by-uuid/ | grep "${NIX_CONFIG_INST_DISK_1##*/}${PART_1}"

pause "Press ENTER to continue..."
git pull

echo -e "\n"
echo -e "#########################"
echo -e "NixOS installation"
echo -e "#########################"
echo -e "\n"

pause "Press ENTER to begin the NixOS installation when ready..."

writeLog "INFO" "Installing NixOS system onto ${INST_HOSTNAME} and applying configuration"

nixos-install \
	--verbose \
	--show-trace \
	--no-root-passwd \
	--flake ".#${INST_HOSTNAME}" \
	--impure \
	--root /mnt || {
		writeLog "ERROR" "Failed to install NixOS"
		exit 87
	}

writeLog "INFO" "Unmounting file systems"

umount -Rl /mnt || {
	writeLog "ERROR" "Failed to unmount HDDs"
	exit 86
}

zpool export -a || {
	writeLog "ERROR" "Failed to export all ZFS pools"
	exit 86
}

writeLog "INFO" "Finished ${SCRIPT}"
