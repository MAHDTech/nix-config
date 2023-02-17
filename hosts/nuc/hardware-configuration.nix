# Do not modify this file!  It was generated by 'nixos-generate-config'
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [

    "nvme"
    "sd_mod"
    "thunderbolt"
    "usb_storage"
    "usbhid"
    "xhci_pci"

  ];

  boot.initrd.kernelModules = [

  ];

  boot.kernelModules = [

    "kvm-intel"

  ];

  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "rpool/nixos/root";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/nix" = {
    device = "rpool/nixos/nix";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/home" = {
    device = "rpool/nixos/home";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/var/lib" = {
    device = "rpool/nixos/var/lib";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/var/log" = {
    device = "rpool/nixos/var/log";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/boot" = {
    device = "bpool/nixos/boot";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/C7E2-7D81";
    fsType = "vfat";
    neededForBoot = true;
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp61s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp7s0u1u4u4.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  hardware = {

    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    enableRedistributableFirmware = true;

  };

}
