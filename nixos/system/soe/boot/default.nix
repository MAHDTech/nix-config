{
  config,
  pkgs,
  ...
}: {
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
    kernelPackages = pkgs.linuxPackages_6_6;

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
      theme = "catppuccin-macchiato";
      themePackages = with pkgs; [
        catppuccin-plymouth
      ];
    };

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
      };

      grub = {
        enable = false;
      };
    };
  };
}
