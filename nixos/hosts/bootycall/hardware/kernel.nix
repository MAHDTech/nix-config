{ pkgs, lib, ... }:
let
  # Use standard Linux 6.12 source from nixpkgs (pre-cached, no downloads)
  kernelSrc = pkgs.linux_6_12.src;
  kernelVersion = pkgs.linux_6_12.version;

  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "linux-bootycall";
    version = kernelVersion;

    src = kernelSrc;

    enableParallelBuilding = true;

    nativeBuildInputs = with pkgs; [
      bc
      bison
      elfutils
      flex
      gmp
      gnumake
      kmod
      libmpc
      mpfr
      openssl
      perl
      python3
      rsync
      zstd
    ];

    buildInputs = with pkgs; [
      zlib
      elfutils
    ];

    # Enable Armv8 Cryptography Extensions if needed
    NIX_CFLAGS_COMPILE = "-march=armv8-a+crypto";

    prePatch = ''
      echo "Copying custom device tree cloudkey-mainline.dts into kernel source tree..."
      cp ${../files/cloudkey-mainline.dts} arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dts

      echo "Registering device tree in Makefile..."
      echo "dtb-\$(CONFIG_ARCH_QCOM) += apq8053-ubnt-cloudkey.dtb" >> arch/arm64/boot/dts/qcom/Makefile
    '';

    configurePhase = ''
      patchShebangs scripts

      # 1. Load the default generic arm64 multi_v8_defconfig
      make ARCH=arm64 defconfig

      # 2. Enable critical built-in drivers for network, storage, and eMMC
      ./scripts/config --enable USB_DWC3
      ./scripts/config --enable USB_DWC3_QCOM
      ./scripts/config --enable USB_NET_AX88179_178A
      ./scripts/config --enable USB_UAS
      ./scripts/config --enable USB_STORAGE
      ./scripts/config --enable MMC_SDHCI_MSM

      # 3. Enable framebuffer and FBTFT ST7735R display drivers
      ./scripts/config --enable FB
      ./scripts/config --enable STAGING
      ./scripts/config --enable FB_TFT
      ./scripts/config --enable FB_TFT_ST7735R

      # 4. Enable required NixOS cgroups and namespace settings
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable NAMESPACES
      ./scripts/config --enable DEVTMPFS
      ./scripts/config --enable DEVTMPFS_MOUNT
      ./scripts/config --enable SECCOMP

      # 5. Disable massive unused subsystems to speed up compilation by 90%+
      ./scripts/config --disable SOUND
      ./scripts/config --disable SND
      ./scripts/config --disable WIRELESS
      ./scripts/config --disable WLAN
      ./scripts/config --disable BT
      ./scripts/config --disable MEDIA_SUPPORT
      ./scripts/config --disable DRM
      ./scripts/config --disable PCI
      ./scripts/config --disable VIRTUALIZATION

      # Disable debug symbols to shrink kernel size under 15MB
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --enable DEBUG_INFO_NONE

      # 6. Re-sync configuration against Kconfig
      make ARCH=arm64 olddefconfig
    '';

    buildPhase = ''
      make ARCH=arm64 -j$NIX_BUILD_CORES Image Image.gz
      make ARCH=arm64 -j$NIX_BUILD_CORES dtbs
      make ARCH=arm64 -j$NIX_BUILD_CORES modules
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp arch/arm64/boot/Image.gz $out/Image.gz
      cp .config $out/config

      # Copy DTB
      mkdir -p $out/dtbs/qcom
      cp arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dtb $out/dtbs/qcom/

      # Install modules
      make ARCH=arm64 INSTALL_MOD_PATH=$out modules_install

      # Clean up build/source symlinks
      rm -rf $out/lib/modules/*/build
      rm -rf $out/lib/modules/*/source
    '';

    passthru = rec {
      modDirVersion = kernelVersion;
      version = modDirVersion;
      dev = kernelBuild;
      moduleBuildDependencies = [ ];
      configfile = "${kernelBuild}/config";
      config = {
        isEnabled = _: true;
        isYes = _: true;
        isNo = _: false;
        isModule = _: false;
        isSet = _: true;
      };
      kernelOlder = v: lib.versionOlder version v;
      kernelAtLeast = v: lib.versionAtLeast version v;
      features = {
        efiBootStub = true;
      };
      commonMakeFlags = [ "ARCH=arm64" ];
    };
  };
in
kernelBuild
