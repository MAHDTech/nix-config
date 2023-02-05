{ config, pkgs, ... }:

{

  boot.supportedFilesystems = [
    "zfs"
  ];

  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  boot.loader.efi = {

    efiSysMountPoint = "/boot/efi";
    canTouchEfiVariables = true;

  };

  boot.loader.generationsDir.copyKernels = true;

  boot.loader.grub = {

    enable = false;

    version = 2;

    efiInstallAsRemovable = true;
    copyKernels = true;
    efiSupport = true;
    zfsSupport = true;

    extraPrepareConfig = ''
      mkdir -p /boot/efis
      for DISK in /boot/efis/*;
      do
          mount $DISK ;
      done
      mkdir -p /boot/efi
      mount /boot/efi
    '';

    extraInstallCommands = ''
      ESP_MIRROR=$(mktemp -d)
      cp -r /boot/efi/EFI $ESP_MIRROR
      for DISK in /boot/efis/*;
      do
          cp -r $ESP_MIRROR/EFI $DISK
      done
      rm -rf $ESP_MIRROR
    '';

    devices = [
      "/dev/nvme0n1"
    ];

  };

}
