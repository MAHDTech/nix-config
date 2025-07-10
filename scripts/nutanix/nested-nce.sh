#!/bin/bash

# Name: nested-nce.sh
# Description: Builds a Nutanix Community Edition ISO that can run nested in another Hypervisor.

clear
set -euo pipefail

#########################
# CONSTANTS
#########################

# spellchecker:ignore-next-line
declare -r ISO_NAME="phoenix.x86_64-fnd_5.6.1_patch-aos_6.8.1_ga"
declare -r DEPENDENCIES=(
	mkisofs
	zcat
	cpio
	gzip
	tar
)

declare WORKING_DIR

#########################
# Declarations
#########################

WORKING_DIR=$(pwd)

#########################
# Functions
#########################

function msg() {
	local LEVEL=${1:-"info"}
	local MESSAGE=${2:-"No message provided"}

	case ${LEVEL^^} in
	"DEBUG")
		echo -e "\033[34m[DEBUG]\033[0m ${MESSAGE}"
		;;
	"INFO")
		echo -e "\033[32m[INFO]\033[0m ${MESSAGE}"
		;;
	"WARNING")
		echo -e "\033[33m[WARNING]\033[0m ${MESSAGE}"
		;;
	"ERROR")
		echo -e "\033[31m[ERROR]\033[0m ${MESSAGE}"
		;;
	esac
	return 0
}

function cleanup() {
	msg "INFO" "Cleaning up..."

	# Unmount ISO if mounted
	if mountpoint -q "${WORKING_DIR}/mntdir/${ISO_NAME}" 2>/dev/null; then
		msg "INFO" "Unmounting ISO..."
		sudo umount "${WORKING_DIR}/mntdir/${ISO_NAME}" || true
	fi

	msg "INFO" "Cleaning up temporary directories..."

	# Only remove directories we created, not mounted content
	rm -rf "${WORKING_DIR}/tmpdir" || true
	rm -rf "${WORKING_DIR}/mntdir" || true

	msg "INFO" "Cleanup complete!"

	return 0
}

#########################
# Pre-flight checks
#########################

# Check if running as root (needed for mounting)
if [[ $EUID -eq 0 ]]; then
	msg "ERROR" "This script should not be run as root. Please run as a regular user with sudo privileges."
	exit 1
fi

# Check if the ISO exists.
if [[ ! -f "${WORKING_DIR}/iso/${ISO_NAME}.iso" ]]; then
	msg "ERROR" "${ISO_NAME} does not exist in ${WORKING_DIR}/iso. Please download the ISO from the Nutanix Community Edition website and place it in the ${WORKING_DIR}/iso directory."
	exit 1
fi

# Check if we have sudo privileges
if ! sudo -n true 2>/dev/null; then
	msg "ERROR" "This script requires sudo privileges for mounting ISO files."
	exit 1
fi

# Make sure all dependencies are installed.
for DEPENDENCY in "${DEPENDENCIES[@]}"; do
	if ! command -v "${DEPENDENCY}" &>/dev/null; then
		msg "ERROR" "${DEPENDENCY} could not be found, please install it."
		exit 1
	fi
done

#########################
# Main
#########################

msg "INFO" "Setting trap for cleanup..."
trap cleanup EXIT SIGINT SIGTERM

msg "INFO" "Creating directories..."

mkdir -p "${WORKING_DIR}/tmpdir"
mkdir -p "${WORKING_DIR}/mntdir"
mkdir -p "${WORKING_DIR}/output"

# Test if output directory is writable
if [[ ! -w "${WORKING_DIR}/output" ]]; then
	msg "ERROR" "Output directory ${WORKING_DIR}/output is not writable."
	exit 1
fi

msg "INFO" "Mounting ISO..."

sudo mkdir -p "${WORKING_DIR}/mntdir/${ISO_NAME}"
sudo mount -t iso9660 -o loop "${WORKING_DIR}/iso/${ISO_NAME}.iso" "${WORKING_DIR}/mntdir/${ISO_NAME}"

msg "INFO" "Unpacking ISO..."

# Create the target directory first
mkdir -p "${WORKING_DIR}/tmpdir/${ISO_NAME}.iso"

# Copy contents from mounted ISO to temp directory
pushd "${WORKING_DIR}/mntdir/${ISO_NAME}"
tar cf - . | (
	cd "${WORKING_DIR}/tmpdir/${ISO_NAME}.iso"
	tar xfp -
)
popd

msg "INFO" "Unpacking initrd..."

mkdir -p "${WORKING_DIR}/tmpdir/initrd"
pushd "${WORKING_DIR}/tmpdir/initrd"
zcat "${WORKING_DIR}/mntdir/${ISO_NAME}/boot/initrd" | cpio -ivd
popd

msg "INFO" "Patching scripts..."

# Change to the initrd directory for patching
pushd "${WORKING_DIR}/tmpdir/initrd"

# Check if there are any Python files to patch
if find . -type f -iname "*.py" | grep -q .; then
	msg "INFO" "Found Python files, applying patches..."
	find . -type f -iname "*.py" -exec sed -i 's/\/sys\/devices\/pci/\/sys\/devices\/LNXSYSTM/g' "{}" \;
	msg "INFO" "Patches applied successfully"
else
	msg "WARNING" "No Python files found to patch"
fi

popd

msg "INFO" "Packing initrd..."

mkdir -p "${WORKING_DIR}/tmpdir/initrd-packed"
pushd "${WORKING_DIR}/tmpdir/initrd"
find . | cpio -o -H newc | gzip -9 >"${WORKING_DIR}/tmpdir/initrd-packed/initrd"
popd

msg "INFO" "Replacing initrd in ISO contents..."

# Replace the original initrd with our patched version
rm -f "${WORKING_DIR}/tmpdir/${ISO_NAME}.iso/boot/initrd"
cp "${WORKING_DIR}/tmpdir/initrd-packed/initrd" "${WORKING_DIR}/tmpdir/${ISO_NAME}.iso/boot/"

msg "INFO" "ISO contents prepared for final packaging."
msg "INFO" "You can now make manual changes to the ISO contents if needed."
msg "INFO" "Location: ${WORKING_DIR}/tmpdir/${ISO_NAME}.iso"
echo
read -rp "Press Enter when ready to create the final ISO, or Ctrl+C to abort..."

pushd "${WORKING_DIR}/tmpdir/${ISO_NAME}.iso"
mkisofs -o "${WORKING_DIR}/output/${ISO_NAME}-hv-mkiso.iso" -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "PHOENIX" .
popd

msg "INFO" "Done!"

ls -al "${WORKING_DIR}/output"

if ! command -v qemu-system-x86_64 &>/dev/null; then
	msg "WARNING" "qemu-system-x86_64 could not be found, unable to run a boot test."
	msg "INFO" "You can test the ISO manually by booting it in a virtual machine."
else
	msg "INFO" "Attempting boot test..."
	qemu-system-x86_64 -boot d -cdrom "${WORKING_DIR}/output/${ISO_NAME}-hv-mkiso.iso" -m 2048 -nographic -enable-kvm
fi
