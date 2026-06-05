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

    # Apply all 32 CIX enablement patches sequentially
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

      # ── Phase 1: Load CIX's official defconfig ──────────────────────────────
      # Use CIX Technology's tested defconfig for the Orion O6 / Sky1 SoC.
      # This is a purpose-built ~3,000-option config that includes all CIX
      # display (DRM_CIX, LINLONDP, TRILIN_DPSUB), USB-C (CDNSP, RTS5453,
      # TYPEC=y, UCSI), PHY (CIX_USBDP), GPU (PANTHOR), audio (HDA CIX),
      # and peripheral drivers in a validated configuration.
      cp ${cixPatches}/config/config-7.0.defconfig .config

      # Single olddefconfig pass: resolve the full Kconfig dependency tree.
      make ARCH=arm64 olddefconfig

      # ── Phase 2: NixOS-specific overrides ───────────────────────────────────
      # IMPORTANT: All ./scripts/config calls MUST go AFTER olddefconfig.
      # Only options that differ from CIX's defconfig or are NixOS-specific
      # need to be set here.

      # --- Fallback display (not in CIX defconfig) ---
      ./scripts/config --enable DRM_SIMPLEDRM

      # --- Display pipeline extras (not in CIX defconfig, may be auto-selected) ---
      ./scripts/config --enable DRM_LINLONDP_CLOCK_FIXED
      ./scripts/config --module DRM_TRILIN_CADENCE_PHY

      # --- Strict devmem for kernel security (not in CIX defconfig) ---
      ./scripts/config --enable STRICT_DEVMEM

      # --- NVMe: force built-in for robust early-boot root mount ---
      # CIX defconfig has NVMe as module; NixOS needs built-in for root on NVMe
      ./scripts/config --enable BLK_DEV_NVME

      # --- Persistent crash capture via block device (pstore-blk) ---
      # Captures panic/oops/console logs to a dedicated 16M raw partition
      # Survives reboot and power loss (unlike ramoops which needs reserved RAM)
      ./scripts/config --enable PSTORE
      ./scripts/config --enable PSTORE_BLK
      ./scripts/config --enable PSTORE_CONSOLE
      ./scripts/config --enable PSTORE_PMSG
      ./scripts/config --enable PSTORE_RAM

      # --- NixOS boot requirements (not in CIX defconfig) ---
      ./scripts/config --enable DEVTMPFS_MOUNT
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable SECCOMP
      ./scripts/config --module TCG_TIS
      ./scripts/config --module USB_UHCI_HCD

      # --- BTRFS crypto dependencies (not in CIX defconfig) ---
      # NixOS uses BTRFS with crc32c checksums; blake2b and xxhash are also
      # required as loadable modules for the initrd to mount the root filesystem.
      ./scripts/config --module CRYPTO_BLAKE2B
      ./scripts/config --module CRYPTO_CRC32C
      ./scripts/config --module CRYPTO_XXHASH

      # --- NixOS filesystem codepage support (not in CIX defconfig) ---
      ./scripts/config --module NLS_CP437
      ./scripts/config --module NLS_UTF8

      # --- USB Ethernet drivers (specific adapters not in CIX defconfig) ---
      ./scripts/config --module USB_NET_AX88179_178A
      ./scripts/config --module USB_NET_CDCETHER
      ./scripts/config --module USB_NET_CDC_NCM

      # --- Disable debug symbols to reduce build size and compile time ---
      # CIX defconfig enables BTF and DWARF5; disable to save ~500MB build output
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --disable DEBUG_INFO_BTF
      ./scripts/config --disable DEBUG_INFO_DWARF5
      ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT

      # --- Disable irrelevant PCIe GPU drivers (CIX defconfig enables these) ---
      ./scripts/config --disable DRM_AMDGPU
      ./scripts/config --disable DRM_NOUVEAU
      ./scripts/config --disable DRM_RADEON

      # ── Phase 3: Validation gate ─────────────────────────────────────────
      # Verify critical CIX and NixOS options survived configuration.
      # If any are missing, the build fails immediately rather than
      # producing a kernel with silently disabled drivers.
      echo "Validating kernel configuration..."
      MISSING=0
      for opt in \
        DRM_CIX DRM_LINLONDP DRM_TRILIN_DPSUB DRM_TRILIN_DP_CIX \
        DRM_CIX_EDP_PANEL DRM_PANTHOR \
        PHY_CIX_USBDP PWM_SKY1 CIX_DSP \
        USB_CDNSP TYPEC TYPEC_RTS5453 \
        BLK_DEV_NVME PSTORE PSTORE_BLK; do
        if ! grep -q "CONFIG_''${opt}=[ym]" .config; then
          echo "FATAL: CONFIG_''${opt} is not enabled in .config!" >&2
          MISSING=$((MISSING + 1))
        fi
      done
      if [ "$MISSING" -gt 0 ]; then
        echo "" >&2
        echo "ERROR: $MISSING required kernel config option(s) are missing." >&2
        echo "This likely means a Kconfig 'depends on' prerequisite is unmet." >&2
        echo "Check the Kconfig files in the patched source for dependency chains." >&2
        exit 1
      fi
      echo "All critical kernel config options verified."
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
      mkdir -p $out/dtbs/cix
      cp arch/arm64/boot/dts/cix/*.dtb $out/dtbs/cix/

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
      cp arch/arm64/Makefile $out/lib/modules/${modDirVersion}/build/arch/arm64/

      # Copy scripts and tools which contain host-compiled binaries needed by make modules
      cp -r scripts $out/lib/modules/${modDirVersion}/build/
      cp -r tools $out/lib/modules/${modDirVersion}/build/

      # Clean up intermediate .o and .cmd files in build/scripts and build/tools to save space
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/scripts -name "*.cmd" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.o" -exec rm -f {} +
      find $out/lib/modules/${modDirVersion}/build/tools -name "*.cmd" -exec rm -f {} +

      # Remove dangling symlinks from the kernel build tree.
      # The kernel source has symlinks in two places that point to dirs we don't copy:
      #   - scripts/dtc/include-prefixes/{arm,mips,powerpc,riscv,...} -> arch/*/boot/dts
      #     (we only ship arch/arm64; other arch DTS dirs are irrelevant for this build)
      #   - tools/testing/selftests/{bpf,vfio,powerpc,...} -> kernel/bpf/, drivers/dma/, arch/powerpc/
      #     (kernel self-tests are not needed for out-of-tree NPU/VPU module builds)
      # Nix's fixupPhase noBrokenSymlinks check will fail on these, so remove them now.
      find $out/lib/modules/${modDirVersion}/build -xtype l -delete
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
