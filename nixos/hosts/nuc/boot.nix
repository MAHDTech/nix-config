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
    consoleLogLevel = 4;

    initrd = {
      enable = true;
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

    # Wiki https://nixos.wiki/wiki/Linux_kernel
    # Kernel (stable)
    #kernelPackages = pkgs.linuxPackages_latest;
    # Kernel (testing)
    #kernelPackages = pkgs.linuxPackages_testing;
    # Kernel (Pinned version) https://kernel.org/
    kernelPackages = pkgs.linuxPackages_6_10;

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
      font = "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf";
      # theme = "glowing";
      # theme = "matrix";
      theme = "catppuccin-macchiato";
      themePackages = with pkgs; [
        adi1090x-plymouth-themes
        catppuccin-plymouth
        plymouth-matrix-theme
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

      package = pkgs.zfs;

      extraPools = zfsPoolNames;

      devNodes = "/dev/disk/by-partuuid";

      forceImportAll = true;

      allowHibernation = false;
    };
  };
}
