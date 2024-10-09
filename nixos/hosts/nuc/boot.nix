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
    initrd = {
      systemd = {
        enable = true;
      };
      kernelModules = [];
    };

    extraModulePackages = with config.boot.kernelPackages; [acpi_call];

    kernelModules = [
      "kvm_intel"
      "acpi_call"
    ];

    # NOTE: Do NOT set nomodeset with Intel GPU as they require kernel mode-setting.
    kernelParams = [
      "acpi_osi=Linux"
      "acpi_backlight=native"

      "nohibernate"
      "zfs.zfs_arc_max=12884901888"

      "usbcore.autosuspend=-1"

      "quiet"
    ];

    plymouth = {
      enable = true;
      theme = "glowing";
      themePackages = with pkgs; [
        plymouth-matrix-theme
        adi1090x-plymouth-themes
      ];
    };

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
