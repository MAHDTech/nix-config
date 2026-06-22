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
      # Android aboot/LK only understands gzip ramdisks; NixOS defaults to zstd
      compressor = "gzip";
      compressorArgs = [ "-9" ];

      includeDefaultModules = false;
      availableKernelModules = lib.mkForce [
        # Hardware drivers
        "sdhci_msm" # eMMC controller
        "dwc3_qcom" # USB controller
        "xhci_hcd" # xHCI controller
        "ax88179_178a" # ASIX AX88179 USB Ethernet adapter (eth0)
        # Filesystems
        "ext4" # Filesystem for root / data partitions
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
      # Stream early kernel log to JONS (via gateway router MAC on different subnet)
      "netconsole=6666@10.10.200.200/eth0,6666@10.10.1.93/74:ac:b9:3f:15:a6"
      "pstore.backend=ramoops"
      "ramoops.ecc=1"
      # Forward journal messages to kmsg so ramoops captures them after journald starts
      "systemd.journald.forward_to_kmsg=1"
      "usbcore.autosuspend=-1"
      "printk.time=1"
      "module_blacklist=uas,usb_storage"
    ];
  };

  # Filesystems partition mappings
  fileSystems = {
    "/" = {
      device = "/dev/mmcblk0p46";
      fsType = "ext4";
      options = [
        "noatime"
        "nodiratime"
        "commit=60"
      ];
    };
    "/mnt/hdd" = {
      device = "/dev/sda5";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "noatime"
      ];
    };
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
