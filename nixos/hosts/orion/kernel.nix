{
  pkgs,
  lib,
  ...
}:

let
  modDirVersion = "7.0.0";

  # Fetch CIX Technology's mainline patches repository
  # Pinned to specific commit SHA for reproducibility — update with date comment when bumping
  # Latest verified: 2026-05-07 — "DPTSW-23786: update README about firmware requirement"
  cixPatches = pkgs.fetchFromGitHub {
    owner = "cixtech";
    repo = "cix-linux-main";
    rev = "3aad82491a599648d87ba1c47cec7968862fa165"; # 2026-05-07
    hash = "sha256-ntc23Nh3eOWgRcfZTTUWigLrs/LqEtIrYhFwiFiSDUc=";
  };

  # Build the custom patched v7.0 kernel
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "linux-cix-mainline";
    version = modDirVersion;

    src = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.tar.xz";
      hash = "sha256-u39tgLOHx1e30Uu5MCj8uQ95PFwNNnc27oFaEAs4kfA=";
    };

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
      nettools
      openssl
      perl
      python3
      rsync
      util-linux
      zlib
      zstd
    ];

    buildInputs = with pkgs; [
      zlib
      elfutils
    ];

    # Enable Armv8 Cryptography Extensions (AES/NEON) to fix crypto/aegis128-neon-inner assembler failures
    NIX_CFLAGS_COMPILE = "-march=armv8-a+crypto";

    # Apply all 32 enablement patches sequentially
    prePatch = ''
      echo "Applying CIX mainline patches from ${cixPatches}..."
      for patch in ${cixPatches}/patches-7.0/*.patch; do
        echo "Applying $patch"
        patch -p1 < "$patch"
      done
    '';

    configurePhase = ''
      patchShebangs scripts
      patchShebangs tools

      # Use our whitelisted local defconfig (Automated Hardware Profile)
      cp ${./files/config/orion.defconfig} .config

      # Enable core TPM 2.0 drivers (physical TPM chip on Orion)
      ./scripts/config --enable TCG_TPM
      ./scripts/config --enable TCG_TIS
      ./scripts/config --enable TCG_TIS_CORE

      # Enable display, simpledrm, and panthor GPU drivers as built-ins to prevent console boot hangs
      ./scripts/config --enable DRM_SIMPLEDRM
      ./scripts/config --enable DRM_PANEL_SIMPLE
      ./scripts/config --enable DRM_PANEL_EDP
      ./scripts/config --module DRM_PANTHOR

      # Run olddefconfig to expand it cleanly for our build
      make ARCH=arm64 olddefconfig

      # Ensure critical NixOS installer and system parameters are enabled
      ./scripts/config --enable EXT4_FS
      ./scripts/config --enable DEVTMPFS
      ./scripts/config --enable DEVTMPFS_MOUNT
      ./scripts/config --module ISO9660_FS
      ./scripts/config --module SQUASHFS
      ./scripts/config --module OVERLAY_FS
      ./scripts/config --module BLK_DEV_LOOP
      ./scripts/config --enable MD
      ./scripts/config --enable BLK_DEV_DM
      ./scripts/config --enable DM_CRYPT
      ./scripts/config --module VFAT_FS
      ./scripts/config --module FAT_FS
      ./scripts/config --module NLS_CP437
      ./scripts/config --module NLS_ISO8859_1
      ./scripts/config --module NLS_UTF8

      # Enable systemd support requirements
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable AUTOFS_FS
      ./scripts/config --enable TMPFS_POSIX_ACL
      ./scripts/config --enable SECCOMP

      # Enable standard USB Ethernet drivers (UGREEN CR111 and common USB-C docks)
      # Note: PCIe WiFi on Orion O6 is Intel AX210 (iwlwifi) — not MT7925E
      # AX210 uses linux-firmware blobs via hardware.enableRedistributableFirmware
      ./scripts/config --enable USB_NET_DRIVERS
      ./scripts/config --module USB_NET_AX88179_178A
      ./scripts/config --module USB_RTL8152
      ./scripts/config --module USB_USBNET
      ./scripts/config --module USB_NET_CDCETHER
      ./scripts/config --module USB_NET_CDC_NCM
      ./scripts/config --module USB_NET_RNDIS_HOST

      # SBSA Generic Watchdog: demote from built-in (=y) to module (=m)
      # The defconfig has CONFIG_ARM_SBSA_WATCHDOG=y which is compiled built-in.
      # Built-in drivers are immune to module_blacklist= kernel param.
      # Demoting to =m makes the blacklist effective as a belt-and-suspenders measure.
      # (nowatchdog param already suppresses it at platform level regardless)
      ./scripts/config --module ARM_SBSA_WATCHDOG

      # NVMe: force built-in for robust early-boot root mount
      # CONFIG_BLK_DEV_NVME=m works via initrd but =y eliminates any module-load race
      ./scripts/config --enable BLK_DEV_NVME

      # CIX DSP communications driver (HiFi5 DSP IPC/mailbox)
      # Prerequisite for future HDMI/DP audio when SND_HDA_CIX_IPBLOQ lands upstream
      # Tracking: https://github.com/cixtech/cix-linux-main (DP Sound: TODO as of 2026-05-07)
      ./scripts/config --module CIX_DSP

      # Disable debug symbols and BTF to reduce build size, compile time, and memory usage
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --disable DEBUG_INFO_BTF
      ./scripts/config --disable DEBUG_INFO_DWARF5
      ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT

      # Disable massive unnecessary PCIe graphics drivers to avoid compilation failures and speed up builds
      ./scripts/config --disable DRM_AMDGPU
      ./scripts/config --disable DRM_NOUVEAU
      ./scripts/config --disable DRM_RADEON

      # Re-sync configuration
      make ARCH=arm64 olddefconfig
    '';

    buildPhase = ''
      # Compile the kernel image, device tree blobs, and modules
      make ARCH=arm64 -j$NIX_BUILD_CORES Image
      make ARCH=arm64 -j$NIX_BUILD_CORES dtbs
      make ARCH=arm64 -j$NIX_BUILD_CORES modules
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp .config $out/config

      # Copy DTBs
      mkdir -p $out/boot/dts/cix
      cp arch/arm64/boot/dts/cix/*.dtb $out/boot/dts/cix/

      # Install kernel modules
      make ARCH=arm64 INSTALL_MOD_PATH=$out modules_install

      # Populate build directory for out-of-tree kernel modules (instead of deleting it)
      rm -f $out/lib/modules/*/build
      rm -f $out/lib/modules/*/source

      mkdir -p $out/lib/modules/${modDirVersion}/build
      cp Makefile Kbuild .config Module.symvers System.map $out/lib/modules/${modDirVersion}/build/

      cp -r include $out/lib/modules/${modDirVersion}/build/
      mkdir -p $out/lib/modules/${modDirVersion}/build/arch/arm64
      cp -r arch/arm64/include $out/lib/modules/${modDirVersion}/build/arch/arm64/

      # Copy scripts and tools which contain host-compiled binaries needed by make modules
      cp -r scripts $out/lib/modules/${modDirVersion}/build/
      cp -r tools $out/lib/modules/${modDirVersion}/build/

      # Clean up intermediate .o and .cmd files in build/scripts and build/tools to save space
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.cmd" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.cmd" -exec rm -f {} +
    '';

    # Satisfy kernel modules and build expectations (e.g. for NPU/VPU drivers)
    passthru = rec {
      modDirVersion = "7.0.0";
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
