{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./hardware
    ../../system/installer/base.nix
  ];

  # Map standard image build to bootImg for flake package builds
  system.build.image = lib.mkForce config.system.build.bootImg;

  networking.hostName = "installer-bootycall";
  networking.hostId = "def00005";

  # NOTE: Timebomb panic timer removed — was used for blind debugging with ramoops.
  # To re-enable for debugging, uncomment the service below:
  # boot.initrd.systemd.services.timebomb = {
  #   description = "Timebomb Panic";
  #   wantedBy = [ "sysinit.target" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = pkgs.writeShellScript "timebomb" ''
  #       sleep 120
  #       echo "120 SECONDS PASSED! PANICKING!" > /dev/kmsg || true
  #       echo 1 > /proc/sys/kernel/sysrq || true
  #       echo c > /proc/sysrq-trigger || true
  #     '';
  #     StandardOutput = "kmsg";
  #     StandardError = "kmsg";
  #   };
  # };

  # Remove the hardcoded ext4 root from hardware-configuration.nix
  # so the initrd can use the live-CD logic to find the squashfs/iso
  fileSystems."/" = lib.mkForce {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  # Enable SSH inside the installer for NixOS Anywhere (if needed)
  services.openssh.enable = true;

  system.build.bootImg = pkgs.stdenv.mkDerivation {
    pname = "bootycall-installer-bundle";
    version = "1.0.0";

    nativeBuildInputs = [ pkgs.android-tools ];

    buildCommand = ''
      mkdir -p $out
      cat ${config.system.build.kernel}/Image.gz ${config.system.build.kernel}/dtbs/qcom/apq8053-ubnt-cloudkey.dtb > Image.gz-dtb
      mkbootimg \
        --kernel Image.gz-dtb \
        --ramdisk ${config.system.build.initialRamdisk}/initrd \
        --cmdline "console=ttyMSM0,115200n8 earlycon loglevel=8 net.ifnames=0 netconsole=6666@10.10.200.200/eth0,6666@10.10.1.93/74:ac:b9:3f:15:a6 pstore.backend=ramoops ramoops.ecc=1 systemd.journald.forward_to_kmsg=1 init=${config.system.build.toplevel}/init" \
        --base 0x80000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x00000100 \
        --pagesize 4096 \
        --output $out/boot.img

      # Copy the ISO image so the user can flash it to the root partition
      cp ${config.system.build.isoImage}/iso/*.iso $out/rootfs.iso
    '';
  };
}
