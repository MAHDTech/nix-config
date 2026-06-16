{
  lib,
  pkgs,
  ...
}:
{
  boot = {
    # Custom kernel setup (Placeholder - we will compile modern kernel with custom DTB)
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # Disable GRUB as we build a custom boot.img
    loader.grub.enable = false;

    initrd = {
      includeDefaultModules = false;
      availableKernelModules = [
        "sdhci_msm" # eMMC controller
        "dwc3_qcom" # USB controller
        "xhci_hcd" # xHCI controller
        "uas" # USB Attached SCSI (for SATA HDD bridge)
        "usb_storage" # Fallback USB storage
        "ax88179_178a" # ASIX AX88179 USB Ethernet adapter (eth0)
      ];
    };

    kernelParams = [
      "console=ttyHSL0,115200n8" # Stock serial console
      "console=tty0"
      # Stream early kernel log to JONS (via gateway router MAC on different subnet)
      "netconsole=6666@10.10.200.200/eth0,6666@10.10.1.93/74:ac:b9:3f:15:a6"
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
