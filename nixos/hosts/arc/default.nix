# ==========================================================================
#  ARC — AMD Ryzen Desktop with Intel ARC B580 GPU
#
#  Disko-based host with BTRFS RAID 0 across 2× NVMe.
#
#  Changes from original JONS host:
#    - Replaced hardware-configuration.nix with disko.nix (BTRFS subvolumes)
#    - ESP moved from USB drive to NVMe (no USB boot dependency)
#    - Bootloader changed from GRUB to systemd-boot (UEFI native)
#    - Removed ZFS (root filesystem is now BTRFS)
# ==========================================================================
{
  config,
  lib,
  ...
}:
{
  imports = [
    # disko replaces hardware-configuration.nix for disk layout
    ./disko.nix

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/intel

    # Load system standard-operating-environment.
    ../../system/soe

    # System configuration
    ../../system/config/audio
    ../../system/config/bluetooth
    ../../system/config/disk/gparted
    ../../system/config/fonts
    ../../system/config/power
    ../../system/config/printing
    ../../system/config/services

    # Theme
    ../../system/config/theme/catppuccin

    # Desktop
    ../../system/config/hardware/desktop
    ../../system/config/network/wireless
    ../../system/config/services/upower

    # Networking
    ../../system/config/network/hosts.nix

    # Desktop Environment
    ../../system/config/desktop-environment/hyprland.nix

    # Tailscale
    ../../system/config/services/tailscale

    # Desktop Applications and Services
    ../../system/config/programs/1password
    ../../system/config/services/trezor

    # Docker
    ../../system/config/virtualisation/docker

    # QEMU/KVM Virtualisation
    ../../system/config/virtualisation/host/qemu

    # Games
    ../../system/config/games
  ];

  boot = {
    supportedFilesystems = [
      "btrfs"
      "cifs"
      "exfat"
      "f2fs"
      "nfs"
      "ntfs"
      "vfat"
      "xfs"
    ];

    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];

      kernelModules = [ ];
    };

    kernelModules = [
      "kvm-amd"
    ];

    kernelParams = [
      "mitigations=off"
      "threadirqs"
    ];

    extraModulePackages = [ ];

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = "ARC";
    hostId = "653850a3";

    useDHCP = lib.mkDefault false;
    interfaces = {
      enp10s0 = {
        name = "enp10s0";
        useDHCP = false;
        mtu = lib.mkForce 9000;
      };
      br0 = {
        name = "br0";
        useDHCP = true;
        mtu = 9000;
      };
    };
    bridges = {
      br0 = {
        interfaces = [ "enp10s0" ];
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
  };

  swapDevices = [ ];
}
