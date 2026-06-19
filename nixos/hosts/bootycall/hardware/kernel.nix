{ pkgs, lib, ... }:
let
  # MSM8953-mainline community kernel — the only tree with complete
  # APQ8053/MSM8953 device tree and driver support.
  # https://github.com/msm8953-mainline/linux
  kernelVersion = "7.0.9";
  kernelSrc = pkgs.fetchFromGitHub {
    owner = "msm8953-mainline";
    repo = "linux";
    rev = "v7.0.9-r0";
    hash = "sha256-JixrsjTjRjuwj6J/aWFIiS0qXr+7NBeR/KtTg8cXPiE=";
  };

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

    prePatch = ''
      echo "Copying custom device tree cloudkey-mainline.dts into kernel source tree..."
      cp ${../files/cloudkey-mainline.dts} arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dts

      echo "Registering device tree in Makefile..."
      echo "dtb-\$(CONFIG_ARCH_QCOM) += apq8053-ubnt-cloudkey.dtb" >> arch/arm64/boot/dts/qcom/Makefile
    '';

    configurePhase = ''
      patchShebangs scripts

      # 1. Start from the community defconfig (already Qualcomm-focused with all QCOM subsystem drivers)
      make ARCH=arm64 defconfig

      # 2. Merge the msm8953 community config fragment on top
      ./scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/msm8953.config

      # 3. CloudKey-specific: USB Ethernet (our ONLY network interface)
      ./scripts/config --enable USB_NET_AX88179_178A
      ./scripts/config --enable USB_NET_DRIVERS
      ./scripts/config --enable USB_USBNET

      # 4. CloudKey-specific: USB storage for SATA HDD bridge (ASM1153E)
      ./scripts/config --enable USB_UAS
      ./scripts/config --enable USB_STORAGE

      # 5. CloudKey-specific: OLED display (ST7735R via SPI) — optional nice-to-have
      ./scripts/config --enable FB
      ./scripts/config --enable STAGING
      ./scripts/config --enable FB_TFT
      ./scripts/config --enable FB_TFT_ST7735R

      # 6. NixOS requirements: cgroups, namespaces, devtmpfs
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable NAMESPACES
      ./scripts/config --enable DEVTMPFS
      ./scripts/config --enable DEVTMPFS_MOUNT
      ./scripts/config --enable SECCOMP

      # 7. Filesystem support for root and data partitions
      ./scripts/config --enable EXT4_FS
      ./scripts/config --enable BTRFS_FS

      # 8. Enable size optimization to keep kernel small for boot.img
      ./scripts/config --disable CC_OPTIMIZE_FOR_PERFORMANCE
      ./scripts/config --enable CC_OPTIMIZE_FOR_SIZE

      # 9. Disable debug symbols to shrink kernel size
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
      ./scripts/config --disable DEBUG_INFO_DWARF4
      ./scripts/config --disable DEBUG_INFO_DWARF5
      ./scripts/config --enable DEBUG_INFO_NONE

      # 10. Disable massive unused subsystems to speed compilation and shrink size
      ./scripts/config --disable SOUND
      ./scripts/config --disable SND
      ./scripts/config --disable WIRELESS
      ./scripts/config --disable WLAN
      ./scripts/config --disable BT
      ./scripts/config --disable MEDIA_SUPPORT
      ./scripts/config --disable DRM
      ./scripts/config --disable VIRTUALIZATION

      # 11. Re-sync configuration against Kconfig
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
