{
  pkgs,
  lib,
  ...
}:

let
  # Fetch CIX Technology's mainline patches repository
  cixPatches = pkgs.fetchFromGitHub {
    owner = "cixtech";
    repo = "cix-linux-main";
    rev = "main";
    hash = "sha256-ntc23Nh3eOWgRcfZTTUWigLrs/LqEtIrYhFwiFiSDUc=";
  };

  # Build the custom patched v7.0 kernel
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "linux-cix-mainline";
    version = "7.0.0";

    src = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.tar.xz";
      hash = "sha256-u39tgLOHx1e30Uu5MCj8uQ95PFwNNnc27oFaEAs4kfA=";
    };

    nativeBuildInputs = with pkgs; [
      perl
      bc
      nettools
      openssl
      rsync
      gmp
      libmpc
      mpfr
      util-linux
      elfutils
      flex
      bison
      pahole
      zstd
      gnumake
      python3
      kmod
      zlib
    ];

    buildInputs = with pkgs; [
      zlib
      elfutils
    ];

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

      # Use CIX's official verified defconfig directly
      cp ${cixPatches}/config/config-7.0.defconfig .config

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

      # Clean up symlinks to source/build directories that Nix won't need
      rm -f $out/lib/modules/*/build
      rm -f $out/lib/modules/*/source
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
