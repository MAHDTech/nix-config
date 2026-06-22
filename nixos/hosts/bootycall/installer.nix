{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./hardware
    ../../system/installer/base.nix
  ];

  # Map standard image build to bootImg for flake package builds
  system.build.image = lib.mkForce config.system.build.bootImg;

  networking = {
    hostName = "installer-bootycall";
    hostId = "def00005";

    # Force DHCP on — the SOE network module sets useDHCP = false,
    # which overrides the installer base's mkDefault true.
    useDHCP = lib.mkForce true;
  };

  # ============================================================
  # SCRIPTED INITRD
  # ============================================================
  # Switch to the scripted (bash) initrd to bypass all the systemd
  # fstab-generator, ordering cycles, and duplicate mount unit
  # issues that plague the systemd initrd with our Android bootloader.
  #
  # The scripted initrd mounts filesystems sequentially via shell
  # commands — no generators, no targets, no daemon-reload.
  #
  # NOTE: The scripted initrd is deprecated in NixOS 26.05 but
  # this is only used for the ONE-TIME installer boot.
  # The final installed system will use systemd initrd with a
  # simple root= mount (no ISO chain complexity).
  boot.initrd = {
    systemd.enable = lib.mkForce false;

    # Prevent udev from trying to change the MAC address of the ASIX adapter,
    # which causes the USB endpoint to reset and the hub to drop!
    # The systemd.network.links option only works if systemd initrd is enabled,
    # so we must manually write the .link file in the scripted initrd!
    preDeviceCommands = ''
      mkdir -p /etc/systemd/network
      cat <<EOF > /etc/systemd/network/99-default.link
      [Match]
      OriginalName=*

      [Link]
      MACAddressPolicy=none
      EOF
    '';

    # Debugging: dump state to kmsg on failure so ramoops captures it
    preFailCommands = ''
      echo "=== INITRD FAILED ===" > /dev/kmsg 2>/dev/null || true
      echo "=== mount state ===" > /dev/kmsg 2>/dev/null || true
      mount > /dev/kmsg 2>/dev/null || true
      echo "=== block devices ===" > /dev/kmsg 2>/dev/null || true
      ls -la /dev/disk/by-label/ > /dev/kmsg 2>/dev/null || true
      echo "=== triggering panic for ramoops ===" > /dev/kmsg 2>/dev/null || true
      sleep 5
      echo 1 > /proc/sys/kernel/sysrq 2>/dev/null || true
      echo c > /proc/sysrq-trigger 2>/dev/null || true
    '';
  };

  # Remove the hardcoded ext4 root from hardware-configuration.nix
  # so the initrd can use the live-CD logic to find the squashfs/iso
  fileSystems."/" = lib.mkForce {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  systemd.network.links."00-mac-override" = {
    matchConfig.OriginalName = "*";
    linkConfig.MACAddressPolicy = "none";
  };

  # Enable SSH inside the installer for NixOS Anywhere (if needed)
  services.openssh.enable = true;

  system.build.bootImg = pkgs.stdenv.mkDerivation {
    pname = "bootycall-installer-bundle";
    version = "1.0.0";

    nativeBuildInputs = [ pkgs.android-tools ];

    buildCommand = ''
      mkdir -p $out
      cat ${config.system.build.kernel}/Image.gz ${config.system.build.kernel}/dtbs/qcom/apq8053-ubnt-cloudkey.dtb > Image.gz-dtb
      mkbootimg \
        --kernel Image.gz-dtb \
        --ramdisk ${config.system.build.initialRamdisk}/initrd \
        --cmdline "console=ttyMSM0,115200n8 earlycon pstore.backend=ramoops ramoops.ecc=1 root=LABEL=${config.isoImage.volumeID} init=${config.system.build.toplevel}/init clk_ignore_unused pd_ignore_unused regulator_ignore_unused usbcore.autosuspend=-1 printk.time=1 systemd.journald.forward_to_kmsg=1 loglevel=8 deferred_probe_timeout=30" \
        --base 0x80000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x00000100 \
        --pagesize 4096 \
        --output $out/boot.img

      # Copy the ISO image so the user can flash it to the root partition
      cp ${config.system.build.isoImage}/iso/*.iso $out/rootfs.iso
    '';
  };
}
