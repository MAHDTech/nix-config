# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    supportedFilesystems = ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "zfs" "ntfs" "cifs"];

    initrd = {
      availableKernelModules = ["nvme" "sd_mod" "thunderbolt" "usb_storage" "usbhid" "xhci_pci"];

      kernelModules = [
        "zfs"
      ];
    };

    kernelModules = [
      "kvm-intel"
    ];

    extraModulePackages = [];
  };

  fileSystems = {
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
    };

    "/boot" = {
      device = "zpool/boot";
      fsType = "zfs";
    };

    "/boot/efi" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_0347023040002297-0:0-part1";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    "/boot/nix" = {
      device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_0347023040002297-0:0-part2";
      fsType = "xfs";
    };

    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
    };

    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
    };

    "/var" = {
      device = "zpool/var";
      fsType = "zfs";
    };

    "/var/lib" = {
      device = "zpool/var/lib";
      fsType = "zfs";
    };

    "/var/lib/docker" = {
      device = "zpool/var/lib/docker";
      fsType = "zfs";
    };

    "/tmp" = {
      device = "zpool/tmp";
      fsType = "zfs";
    };
  };

  swapDevices = [];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp61s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  hardware = {
    cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableRedistributableFirmware = true;
  };
}
