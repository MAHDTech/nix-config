{ lib, pkgs, ... }:
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
    ];

    # Use the latest kernel for newer ARM boards
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

    initrd = {
      availableKernelModules = [
        "nvme"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "uas"
        "r8169" # Realtek network
        "r8152" # Realtek USB network
        "panthor" # Immortalis G720 GPU
        "panfrost"
      ];
      kernelModules = [ "kvm" ];
    };

    kernelParams = [
      "console=ttyAMA0,115200n8"
      "console=tty0"
    ];

    # Modern boot management
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = lib.mkForce "/boot";
      };
    };
  };

  hardware = {
    graphics.enable = true;
    enableRedistributableFirmware = true;
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
