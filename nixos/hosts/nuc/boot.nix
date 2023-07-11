{
  config,
  pkgs,
  ...
}: {
  imports = [
  ];

  environment.systemPackages = with pkgs; [];

  boot = {
    supportedFilesystems = [""];

    # Latest kernel
    kernelPackages = pkgs.linuxPackages_latest;

    extraModulePackages = with config.boot.kernelPackages; [acpi_call];

    kernelModules = ["acpi_call"];

    kernelParams = [
      "acpi_osi=Linux"
      "acpi_backlight=native"

      "nohibernate"

      "usbcore.autosuspend=-1"
    ];

    kernel = {
      sysctl = {
        #"net.ipv6.conf.all.disable_ipv6" = 1;
      };
    };

    loader = {
      timeout = 3;

      efi = {
        efiSysMountPoint = "/boot";
        canTouchEfiVariables = false;
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

        efiInstallAsRemovable = true;
        copyKernels = true;
        efiSupport = true;
        zfsSupport = false;

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
  };
}
