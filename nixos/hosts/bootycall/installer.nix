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

      # Start background panic timer to gather regulators/clocks debug info
      (
        sleep 45
        echo "=== REGULATORS STATE ===" > /dev/kmsg || true
        for r in /sys/class/regulator/regulator.*; do
          if [ -f "$r/name" ]; then
            echo "$(cat "$r/name"): $(cat "$r/microvolt" 2>/dev/null || echo unknown) uV, state: $(cat "$r/state" 2>/dev/null || echo unknown)" > /dev/kmsg || true
          fi
        done
        echo "=== CLOCK SUMMARY ===" > /dev/kmsg || true
        mkdir -p /sys/kernel/debug
        mount -t debugfs none /sys/kernel/debug || true
        if [ -f /sys/kernel/debug/clk/clk_summary ]; then
          while read -r line; do
            echo "CLK: $line" > /dev/kmsg || true
          done < /sys/kernel/debug/clk/clk_summary
        else
          echo "debugfs/clk_summary not found" > /dev/kmsg || true
        fi
        echo "=== USB DEVICES ===" > /dev/kmsg || true
        lsusb -t > /dev/kmsg 2>&1 || true
        echo "=== PANICKING NOW ===" > /dev/kmsg || true
        echo 1 > /proc/sys/kernel/sysrq || true
        echo c > /proc/sysrq-trigger || true
      ) &
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

  systemd.services.panic-timer = {
    description = "Panic timer to dump clocks and regulators";
    wantedBy = [ "sysinit.target" ];
    before = [ "sysinit.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "simple";
    script = ''
      sleep 10
      echo "=== REGULATORS STATE ===" > /dev/kmsg || true
      for r in /sys/class/regulator/regulator.*; do
        if [ -f "$r/name" ]; then
          echo "$(cat "$r/name"): $(cat "$r/microvolt" 2>/dev/null || echo unknown) uV, state: $(cat "$r/state" 2>/dev/null || echo unknown)" > /dev/kmsg || true
        fi
      done
      echo "=== CLOCK SUMMARY ===" > /dev/kmsg || true
      mkdir -p /sys/kernel/debug
      mount -t debugfs none /sys/kernel/debug || true
      if [ -f /sys/kernel/debug/clk/clk_summary ]; then
        while read -r line; do
          echo "CLK: $line" > /dev/kmsg || true
        done < /sys/kernel/debug/clk/clk_summary
      else
        echo "debugfs/clk_summary not found" > /dev/kmsg || true
      fi
      echo "=== USB DEVICES ===" > /dev/kmsg || true
      ${pkgs.usbutils}/bin/lsusb -t > /dev/kmsg 2>&1 || true
      echo "=== PANICKING NOW ===" > /dev/kmsg || true
      echo 1 > /proc/sys/kernel/sysrq || true
      echo c > /proc/sysrq-trigger || true
    '';
  };

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
        --cmdline "console=ttyMSM0,115200n8 earlycon pstore.backend=ramoops ramoops.ecc=1 root=LABEL=${config.isoImage.volumeID} init=${config.system.build.toplevel}/init clk_ignore_unused pd_ignore_unused regulator_ignore_unused module_blacklist=uas,usb_storage usbcore.autosuspend=-1 printk.time=1 systemd.journald.forward_to_kmsg=1 loglevel=8" \
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
