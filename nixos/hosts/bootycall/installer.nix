{ pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
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
      # Example usage of mkbootimg to create the Android boot image:
      # mkbootimg \
      #   --kernel ./Image \
      #   --ramdisk ./initrd \
      #   --dtb ./cloudkey.dtb \
      #   --cmdline "console=ttyHSL0,115200n8 net.ifnames=0 quiet" \
      #   --pagesize 4096 \
      #   --output $out/boot.img
    '';
  };
}
