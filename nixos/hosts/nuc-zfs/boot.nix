{
  config,
  pkgs,
  ...
}: let
  zfsPoolNames = ["bpool" "rpool"];
in {
  imports = [
    ../../system/services/zfs
    {services.zfs.autoScrub.pools = zfsPoolNames;}
  ];

  environment.systemPackages = with pkgs; [];

  boot = {
    supportedFilesystems = ["zfs"];

    # ZFS compatible
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

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
        canTouchEfiVariables = false;
      };

      generationsDir.copyKernels = true;

      systemd-boot = {
        enable = false;

        graceful = true;
        memtest86.enable = true;
        netbootxyz.enable = false;
      };

      grub = {
        enable = true;

        efiInstallAsRemovable = true;
        copyKernels = true;
        efiSupport = true;
        zfsSupport = true;

        # TODO: https://github.com/vinceliuice/grub2-themes
        #theme =

        memtest86 = {enable = true;};

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

        # Enable auto-detection
        useOSProber = true;
      };
    };

    zfs = {
      requestEncryptionCredentials = true;

      # Enable zfsUnstable pkg
      enableUnstable = false;

      extraPools = zfsPoolNames;

      devNodes = "/dev/disk/by-partuuid";

      forceImportAll = true;

      allowHibernation = false;
    };
  };
}
