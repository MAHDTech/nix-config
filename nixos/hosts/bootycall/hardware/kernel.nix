{ pkgs, lib, ... }:
let
  # ===========================================================================
  # MSM8953-mainline community kernel for CloudKey Gen2 Plus
  # ===========================================================================
  # Source: https://github.com/msm8953-mainline/linux
  # This is the only kernel tree with complete APQ8053/MSM8953 DTS and drivers.
  #
  # Build strategy:
  #   - Cross-compilation is configured at the flake level via buildSystem/system
  #   - pkgs.stdenv.buildPlatform / hostPlatform are set correctly by nixpkgs
  #   - Minimal config from allnoconfig + cloudkey.config fragment
  #   - Expected build time: ~3 minutes (cross or native)
  # ===========================================================================

  kernelVersion = "7.1.1";

  kernelSrc = pkgs.fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.1.tar.xz";
    hash = "sha256-UhX6NUHcfn9bzVG/flfxac7G/OUIylTj3IX97hQ3HX0=";
  };

  # -------------------------------------------------------------------------
  # Cross-compilation: automatic based on flake's buildSystem / system
  # -------------------------------------------------------------------------
  # When buildSystem != system (e.g. BOOTYCALL), nixpkgs configures:
  #   pkgs.stdenv.buildPlatform.system = "x86_64-linux"  (the builder)
  #   pkgs.stdenv.hostPlatform.system  = "aarch64-linux"  (the target)
  #   pkgs.buildPackages               = native x86_64 packages
  #
  # When buildSystem == system (e.g. Zenbook), both are "aarch64-linux"
  # and pkgs.buildPackages == pkgs (native build).
  # -------------------------------------------------------------------------
  needsCross = pkgs.stdenv.buildPlatform.system != pkgs.stdenv.hostPlatform.system;

  # buildPackages gives us native tools (x86_64 when cross-compiling)
  hostPkgs = pkgs.buildPackages;

  crossMakeFlags = [
    "ARCH=arm64"
  ]
  ++ lib.optionals needsCross [
    "CROSS_COMPILE=${pkgs.stdenv.cc.targetPrefix}"
  ];

  kernelBuild = hostPkgs.stdenv.mkDerivation {
    pname = "linux-bootycall";
    version = kernelVersion;

    src = kernelSrc;

    patches = [
      ../patches/0001-phy-qcom-qmp-usb-Add-msm8953-support.patch
    ];

    enableParallelBuilding = true;

    # Native build tools (run on the build host)
    nativeBuildInputs =
      with hostPkgs;
      [
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
      ]
      ++ lib.optionals needsCross [
        # Cross-compiler: native binary that outputs aarch64 ELF
        pkgs.stdenv.cc
      ];

    depsBuildBuild = [ hostPkgs.stdenv.cc ];

    buildInputs = with hostPkgs; [
      zlib
      elfutils
    ];

    prePatch = ''
      echo "Copying CloudKey device tree into kernel source tree..."
      cp ${../files/cloudkey-mainline.dts} arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dts

      echo "Registering device tree in Makefile..."
      echo "dtb-\$(CONFIG_ARCH_QCOM) += apq8053-ubnt-cloudkey.dtb" >> arch/arm64/boot/dts/qcom/Makefile

      echo "Exporting fbtft_init_display_from_property function from core..."
      sed -i 's/static int fbtft_init_display_from_property/int fbtft_init_display_from_property/' drivers/staging/fbtft/fbtft-core.c
      echo 'EXPORT_SYMBOL(fbtft_init_display_from_property);' >> drivers/staging/fbtft/fbtft-core.c
      sed -i '/int fbtft_probe_common/i int fbtft_init_display_from_property(struct fbtft_par *par);' drivers/staging/fbtft/fbtft.h

      echo "Patching fb_ssd1306 staging driver to support custom DT init sequence..."
      sed -i '1s/^/#include <linux\/property.h>\n/' drivers/staging/fbtft/fb_ssd1306.c
      sed -i '/static int init_display(struct fbtft_par \*par)/!b;n;a\	if (device_property_present(par->info->device, "init")) {\n\t\tpar->fbtftops.reset(par);\n\t\treturn fbtft_init_display_from_property(par);\n\t}' drivers/staging/fbtft/fb_ssd1306.c
    '';

    configurePhase = ''
      patchShebangs scripts

      # 1. Start from allnoconfig (everything disabled)
      make ${lib.concatStringsSep " " crossMakeFlags} allnoconfig

      # 2. Merge our minimal CloudKey config fragment
      ARCH=arm64 ./scripts/kconfig/merge_config.sh -m .config ${../files/cloudkey.config}

      # 3. Resolve all Kconfig dependencies
      make ${lib.concatStringsSep " " crossMakeFlags} olddefconfig
    '';

    buildPhase = ''
      make ${lib.concatStringsSep " " crossMakeFlags} -j$NIX_BUILD_CORES Image Image.gz
      make ${lib.concatStringsSep " " crossMakeFlags} -j$NIX_BUILD_CORES dtbs
      make ${lib.concatStringsSep " " crossMakeFlags} -j$NIX_BUILD_CORES modules
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp arch/arm64/boot/Image.gz $out/Image.gz
      cp .config $out/config

      # Device tree blob
      mkdir -p $out/dtbs/qcom
      cp arch/arm64/boot/dts/qcom/apq8053-ubnt-cloudkey.dtb $out/dtbs/qcom/

      # Kernel modules
      make ${lib.concatStringsSep " " crossMakeFlags} INSTALL_MOD_PATH=$out modules_install

      # Clean up build/source symlinks
      rm -rf $out/lib/modules/*/build
      rm -rf $out/lib/modules/*/source
    '';

    # NixOS kernel interface compatibility
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
