{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  boot = {
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "sd_mod"
      "sr_mod"
    ];
    growPartition = true;
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 5;
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  networking = {
    useDHCP = lib.mkDefault true;
    useNetworkd = true;
  };
  services = {
    qemuGuest.enable = true;
    cloud-init = {
      enable = true;
      network.enable = true;
      extraPackages = [
        pkgs.nix
        pkgs.nixos-rebuild
        pkgs.git
      ];
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
  };
  time.timeZone = "Australia/Canberra";
  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];
}
