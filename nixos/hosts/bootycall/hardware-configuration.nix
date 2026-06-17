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
      includeDefaultModules = false;
      availableKernelModules = lib.mkForce [
        "sdhci_msm" # eMMC controller
        "dwc3_qcom" # USB controller
        "xhci_hcd" # xHCI controller
        "uas" # USB Attached SCSI (for SATA HDD bridge)
        "usb_storage" # Fallback USB storage
        "ax88179_178a" # ASIX AX88179 USB Ethernet adapter (eth0)
      ];
    };

    kernelParams = [
      "console=ttyMSM0,115200n8" # Mainline serial console
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
