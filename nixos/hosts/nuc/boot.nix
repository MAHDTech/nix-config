{
  config,
  pkgs,
  ...
}: let
  zfsPoolNames = ["zpool"];
in {
  imports = [
    ../../system/services/zfs
    {services.zfs.autoScrub.pools = zfsPoolNames;}
  ];

  environment.systemPackages = with pkgs; [];

  boot = {
    supportedFilesystems = ["zfs"];

    initrd = {
      kernelModules = [];
    };

    extraModulePackages = with config.boot.kernelPackages; [acpi_call];

    kernelModules = ["acpi_call"];

    kernelParams = [
      "acpi_osi=Linux"
      "acpi_backlight=native"

      "nohibernate"
      "zfs.zfs_arc_max=12884901888"

      "usbcore.autosuspend=-1"
    ];

    loader = {
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
      };
    };

    zfs = {
      requestEncryptionCredentials = true;

      # Enable zfsUnstable pkg
      #package = pkgs.zfs_unstable;
      package = pkgs.zfs;

      extraPools = zfsPoolNames;

      devNodes = "/dev/disk/by-partuuid";

      forceImportAll = true;

      allowHibernation = false;
    };
  };
}
