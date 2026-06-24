{
  lib,
  pkgs,
  ...
}:
{
  boot = {
    # Custom mainline kernel compiled with our custom Device Tree
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ./kernel.nix { };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    # Disable software RAID in initrd
    swraid.enable = lib.mkForce false;

    # Disable GRUB as we build a custom boot.img
    loader.grub.enable = false;

    initrd = {
      # Disable systemd initrd to reduce initrd size (avoids 32MB LK boot limit)
      systemd.enable = false;

      # Android aboot/LK only understands gzip ramdisks; NixOS defaults to zstd
      compressor = "xz";
      compressorArgs = [
        "-9"
        "-e"
      ];

      includeDefaultModules = false;
      availableKernelModules = lib.mkForce [
        # Hardware drivers
        "sdhci_msm" # eMMC controller
        "dwc3_qcom" # USB controller
        "xhci_hcd" # xHCI controller
        "ax88179_178a" # ASIX AX88179 USB Ethernet adapter (eth0)
        "uas" # USB Attached SCSI (for internal SSD)
        "usb_storage" # USB Mass Storage (for internal SSD)
        "sd_mod" # SCSI Disk support (REQUIRED for usb_storage/uas block devices)
        # Filesystems
        "ext4" # Filesystem for root / data partitions
        "btrfs" # Filesystem for NixOS root

        "crc32c" # Required checksum module for ext4
        # NixOS Live CD boot chain (iso-image.nix requires these)
        "iso9660" # Read the ISO filesystem on mmcblk0p46
        "squashfs" # Mount the squashfs nix store inside the ISO
        "loop" # Loop-mount the ISO and squashfs images
        "overlay" # Overlay filesystem for writable layer on top of squashfs
        "nls_iso8859-1" # Character set support for ISO9660
      ];

      # Failsafe: if stage-1 initrd fails, force a kernel panic to write ramoops
      systemd.services.panic-dumper = {
        description = "Force panic on boot failure";
        wantedBy = [ "emergency.target" ];
        before = [ "emergency.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeScript "panic-dumper" ''
            #!/bin/sh
            echo "EMERGENCY TARGET REACHED! FORCING PANIC!" > /dev/kmsg
            echo c > /proc/sysrq-trigger
          '';
        };
      };
    };

    kernelParams = [
      "console=ttyMSM0,115200n8" # Mainline serial console
      "console=tty0"
      "earlycon" # Earliest possible console output
      "loglevel=8" # Maximum kernel verbosity for debugging
      "pstore.backend=ramoops"
      "ramoops.ecc=1"
      # Forward journal messages to kmsg so ramoops captures them after journald starts
      "systemd.journald.forward_to_kmsg=1"
      "usbcore.autosuspend=-1"
      "printk.time=1"
      "clk_ignore_unused"
      "pd_ignore_unused"
      "regulator_ignore_unused"
    ];
  };

  # Prevent udev from trying to change the MAC address of the ASIX adapter,
  # which causes the USB endpoint to reset and the entire USB hub (including the SSD) to drop!
  systemd.network.links."00-mac-override" = {
    matchConfig.OriginalName = "*";
    linkConfig.MACAddressPolicy = "none";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
