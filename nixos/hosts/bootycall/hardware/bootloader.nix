{
  pkgs,
  ...
}:
{
  system.boot.loader.id = "cloudkey-bootimg";
  system.build.installBootLoader = pkgs.writeScript "install-cloudkey-bootloader.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    export PATH="${pkgs.android-tools}/bin:${pkgs.coreutils}/bin:$PATH"

    if [ $# -lt 1 ]; then
      echo "Usage: $0 <default-toplevel-path>"
      exit 1
    fi

    PROFILE_DIR="$1"
    KERNEL="$PROFILE_DIR/kernel"
    INITRD="$PROFILE_DIR/initrd"
    DTB="$PROFILE_DIR/dtbs/qcom/apq8053-ubnt-cloudkey.dtb"
    PARAMS="$(cat $PROFILE_DIR/kernel-params | sed 's/root=fstab//g')"

    echo "Building Android boot.img for CloudKey..."
    echo "Kernel: $KERNEL"
    echo "Initrd: $INITRD"
    echo "DTB: $DTB"

    # Combine Kernel and DTB
    cat "$KERNEL" "$DTB" > /tmp/Image.gz-dtb

    # Generate boot.img
    mkbootimg \
      --kernel /tmp/Image.gz-dtb \
      --ramdisk "$INITRD" \
      --cmdline "$PARAMS" \
      --base 0x80000000 \
      --kernel_offset 0x00008000 \
      --ramdisk_offset 0x01000000 \
      --tags_offset 0x00000100 \
      --pagesize 4096 \
      --output /tmp/boot.img

    echo "Flashing boot.img to /dev/mmcblk0p42..."
    dd if=/tmp/boot.img of=/dev/mmcblk0p42 bs=4M conv=fdatasync status=progress

    # Cleanup
    rm -f /tmp/Image.gz-dtb /tmp/boot.img

    echo "Bootloader successfully installed to eMMC!"
  '';
}
