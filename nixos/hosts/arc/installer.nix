# ==========================================================================
#  ARC — Bootable installer ISO
#  AMD Ryzen Desktop with Intel ARC B580 GPU
#
#  This produces a bootable NixOS ISO image with:
#    - All kernel modules needed for ARC hardware
#    - SSH enabled with root password "nixos"
#    - Suitable for booting live and imaging via nixos-anywhere
#
#  Build:  nix build .#arc-image
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
    initrd = {
      availableKernelModules = [
        "ahci"
        "btrfs"
        "nvme"
        "sd_mod"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
    };

    kernelModules = [
      "kvm-amd"
    ];

    kernelParams = [
      "mitigations=off"
    ];

    supportedFilesystems = [
      "btrfs"
      "vfat"
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
    hostName = "arc-installer";
    hostId = "653850a3";
    useDHCP = lib.mkForce true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "26.05";
}
