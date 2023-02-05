{ config, pkgs, ... }:

{

  boot.supportedFilesystems = [
    "zfs"
  ];

  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  boot.loader = {

    timeout = 3;

    efi = {

      efiSysMountPoint = "/boot/efi";
      canTouchEfiVariables = true;

    };

    generationsDir.copyKernels = true;

    systemd-boot = {

      enable = true;

      graceful = true;
      memtest86.enable = true;
      netbootxyz.enable = false;

    };

    grub = {

      enable = false;

      version = 2;
      efiInstallAsRemovable = true;
      copyKernels = true;
      efiSupport = true;
      zfsSupport = true;

      memtest86 = {
        enable = true;
      };

      #extraPrepareConfig = ''
      #  mkdir -p /boot/efis
      #  for DISK in /boot/efis/*;
      #  do
      #      mount $DISK ;
      #  done
      #  mkdir -p /boot/efi
      #  mount /boot/efi
      #'';

      #extraInstallCommands = ''
      #  ESP_MIRROR=$(mktemp -d)
      #  cp -r /boot/efi/EFI $ESP_MIRROR
      #  for DISK in /boot/efis/*;
      #  do
      #      cp -r $ESP_MIRROR/EFI $DISK
      #  done
      #  rm -rf $ESP_MIRROR
      #'';

      device = "nodev"; # UEFI only

    };

  };

  boot.kernelParams = [

    "nohibernate"
    "zfs.zfs_arc_max=12884901888"

  ];

  boot.zfs = {

    extraPools = [
      "bpool"
      "rpool"
    ];

    #devNodes = "/dev/disk/by-id";
    #devNodes = "/dev/disk/by-path";
    devNodes = "/dev/disk/by-partuuid";
    #devNodes = "/dev/disk/by-label";

    forceImportAll = true ;

  };

  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

}
