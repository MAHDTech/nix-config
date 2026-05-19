# ==========================================================================
#  ORION — Bootable installer ISO
#  Radxa Orion O6
#
#  This produces a bootable NixOS ISO image with:
#    - All kernel modules needed for ORION hardware
#    - SSH enabled with root password "nixos"
#    - Suitable for booting live and imaging via nixos-anywhere
#
#  Build:  nix build .#orion-image
#  Write:  dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress
# ==========================================================================
{
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    initrd = {
      availableKernelModules = [
        "btrfs"
        "nvme"
        "sd_mod"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "r8169"
        "r8152"
      ];
    };

    kernelModules = [
      "kvm"
    ];

    kernelParams = [
      "console=ttyAMA0,115200n8"
      "console=tty0"
    ];

    supportedFilesystems = lib.mkForce [
      "btrfs"
      "vfat"
      "ext4"
      "squashfs"
    ];
  };

  # SSH for nixos-anywhere
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
  };

  # Include tools useful during installation
  environment.systemPackages = with pkgs; [
    btrfs-progs
    git
    htop
    parted
    vim
  ];

  networking = {
    hostName = "orion-installer";
    hostId = "def00004";
    useDHCP = lib.mkForce true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  system.stateVersion = "26.05";
}
