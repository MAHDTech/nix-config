{ pkgs, config, ... }:
{
  imports = [
    ./hardware
    ../../system/installer/base.nix
  ];

  # Map standard image build to bootImg for flake package builds
  system.build.image = config.system.build.bootImg;

  networking.hostName = "installer-bootycall";
  networking.hostId = "def00005";

  # Enable SSH inside the installer for NixOS Anywhere (if needed)
  services.openssh.enable = true;

  # Android boot image packaging logic
  # Since this device boots custom Android boot.img via fastboot,
  # we define a custom build target that packages kernel + initrd + DTB.
  system.build.bootImg = pkgs.stdenv.mkDerivation {
    pname = "bootycall-bootimg";
    version = "1.0.0";

    nativeBuildInputs = [ pkgs.android-tools ];

    buildCommand = ''
      mkdir -p $out
      cat ${config.system.build.kernel}/Image.gz ${config.system.build.kernel}/dtbs/qcom/apq8053-ubnt-cloudkey.dtb > Image.gz-dtb
      mkbootimg \
        --kernel Image.gz-dtb \
        --ramdisk ${config.system.build.initialRamdisk}/initrd \
        --cmdline "console=ttyMSM0,115200n8 net.ifnames=0 quiet netconsole=6666@10.10.200.200/eth0,6666@10.10.1.93/74:ac:b9:3f:15:a6" \
        --base 0x80000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x00000100 \
        --pagesize 4096 \
        --output $out/boot.img
    '';
  };
}
