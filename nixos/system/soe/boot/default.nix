{
  pkgs,
  ...
}:

let

  # Determine the systems to allow QEMU emulation for.
  qemuEmulatedSystems =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      # Emulate ARM64 on AMD64
      [ "aarch64-linux" ]
    else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
      # Emulate AMD64 on ARM64
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

      # Static emulators get preloaded by the kernel (fixBinary), so they work
      # inside any chroot without further setup. But pkgsStatic.qemu-user does
      # not link on aarch64: nettle is compiled -fpic, and once all of qemu-user
      # is statically linked the GOT overflows the 32 KiB reach of
      # R_AARCH64_LD64_GOTPAGE_LO15.
      #
      # On aarch64 fall back to the dynamic emulator. The binfmt module then
      # adds /run/binfmt and the interpreter's store path to nix's
      # extra-sandbox-paths, so emulated builds in the nix sandbox still work —
      # only the works-in-any-chroot property is lost.
      preferStaticEmulators = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
    };

    initrd = {
      enable = true;
      kernelModules = [ ];
    };

    kernelPackages = pkgs.linuxPackages_7_2;

    kernelParams = [
      "nohibernate"
      "quiet"
    ];

    # Increase file watcher limit for all users
    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 2048576;
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
        canTouchEfiVariables = false;
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

        editor = false; # Security: prevent kernel command line editing from boot menu
      };

      grub = {
        enable = false;
      };
    };
  };
}
