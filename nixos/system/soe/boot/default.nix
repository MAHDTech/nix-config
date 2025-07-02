{
  config,
  pkgs,
  ...
}:
{
  boot = {
    consoleLogLevel = 4;

    initrd = {
      enable = true;
      systemd = {
        enable = true;
      };
      kernelModules = [ ];
    };

    extraModulePackages = with config.boot.kernelPackages; [ ];

    kernelModules = [
    ];

    # Wiki https://nixos.wiki/wiki/Linux_kernel
    # Kernel (stable)
    #kernelPackages = pkgs.linuxPackages_latest;
    # Kernel (testing)
    #kernelPackages = pkgs.linuxPackages_testing;
    # Kernel (Pinned version) https://kernel.org/
    #kernelPackages = pkgs.linuxPackages_6_12;
    kernelPackages = pkgs.linuxPackages_6_15;
    # NOTE: Don't set when using musnix realtime kernel.

    # NOTE: Do NOT set nomodeset with Intel GPU as they require kernel mode-setting.
    kernelParams = [
      "acpi_osi=Linux"
      "acpi_backlight=native"

      "nohibernate"
      "zfs.zfs_arc_max=12884901888"

      "usbcore.autosuspend=-1"

      "quiet"
    ];

    # Increase file watcher limit for all users
    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 524288;
    };

    plymouth = {
      enable = true;
      font = "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf";
    };

    growPartition = true;

    loader = {
      timeout = 3;

      efi = {
        efiSysMountPoint = "/boot/efi";
        canTouchEfiVariables = true;
      };

      generationsDir = {
        copyKernels = true;
      };

      systemd-boot = {
        enable = true;

        graceful = true;
        memtest86.enable = true;
        netbootxyz.enable = false;

        configurationLimit = 10;

        # Disable bootloader editing for security
        editor = false;
      };

      grub = {
        enable = false;
      };
    };
  };
}
