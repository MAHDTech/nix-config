{
  config,
  lib,
  pkgs,
  ...
}:

let

  # Determine the latest ZFS compatible kernel.
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.match "linux_[0-9]+_[0-9]+" name) != null
    && (builtins.tryEval kernelPackages).success
    && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) pkgs.linuxKernel.packages;

  latestZFSKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );

  # Determine the systems to allow QEMU emulation for.
  qemuEmulatedSystems =
    if pkgs.system == "x86_64-linux" then
      [ "aarch64-linux" ]
    else if pkgs.system == "aarch64-linux" then
      [ "x86_64-linux" ]
    else
      [ ];

in
{
  boot = {
    consoleLogLevel = 4;

    # Enable QEMU emulation for the right systems.
    binfmt = {
      emulatedSystems = qemuEmulatedSystems;
    };

    initrd = {
      enable = true;
      systemd = {
        enable = true;
      };
      kernelModules = [ ];
    };

    # Kernel selection
    #  - 1. If a custom kernel is set as module argument, use that.
    #  - 2. If no custom kernel is set, use the latest ZFS compatible kernel.
    kernelPackages =
      if lib.hasAttr "customKernelPackage" config._module.args then
        # Use the custom kernel override.
        config._module.args.customKernelPackage
      else
        # Default to the latest ZFS compatible kernel.
        latestZFSKernelPackage;

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
      "fs.inotify.max_user_instances" = 512;
      "vm.compact_unevictable_allowed" = 1;
      "vm.swappiness" = 10;
    };

    plymouth = {
      enable = true;
      font = "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf";
    };

    growPartition = true;

    loader = {
      timeout = 10;

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
        memtest86.enable = false;
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
