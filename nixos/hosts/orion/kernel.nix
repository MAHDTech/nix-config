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

      echo "Applying custom fixed regulator ACPI match patch..."
      patch -p1 < ${./files/patches/fixed-regulator-acpi.patch}
    '';

    configurePhase = ''
      patchShebangs scripts
      patchShebangs tools

      # ── Phase 1: Load defconfig and resolve Kconfig defaults ──────────────
      # Use our whitelisted local defconfig (Automated Hardware Profile)
      cp ${./files/config/orion.defconfig} .config

      # Single olddefconfig pass: resolve the full Kconfig dependency tree
      # against the defconfig baseline. All CIX patch-introduced symbols
      # get their default values here.
      make ARCH=arm64 olddefconfig

      # ── Phase 2: Apply ALL config overrides ───────────────────────────────
      # IMPORTANT: All ./scripts/config calls MUST go AFTER olddefconfig.
      # scripts/config does raw text edits that bypass Kconfig dependency
      # resolution. Placing them before olddefconfig causes it to silently
      # discard options whose 'depends on' chains aren't satisfied.
      # By placing them after, these edits become the final word.
      # Any genuine dependency issues will surface as compile errors
      # (which is preferable to silent config drops).

      # --- CIX Display Pipeline (Linlon/Trilinear DP) ---
      ./scripts/config --module DRM_CIX
      ./scripts/config --module DRM_LINLONDP
      ./scripts/config --enable DRM_LINLONDP_CLOCK_FIXED
      ./scripts/config --module DRM_TRILIN_DP_CIX
      ./scripts/config --module DRM_TRILIN_DPSUB
      ./scripts/config --module DRM_TRILIN_CADENCE_PHY
      ./scripts/config --module DRM_CIX_EDP_PANEL

      # --- GPU and Framebuffer ---
      ./scripts/config --enable DRM_SIMPLEDRM
      ./scripts/config --enable DRM_PANEL_SIMPLE
      ./scripts/config --enable DRM_PANEL_EDP
      ./scripts/config --module DRM_PANTHOR

      # --- CIX PWM (needed for eDP backlight) ---
      ./scripts/config --enable PWM_SKY1

      # --- CIX PHY drivers (USB-C DP alt mode, PCIe, USB2/3) ---
      ./scripts/config --enable PHY_CIX_USBDP
      ./scripts/config --disable PHY_CIX_PCIE
      ./scripts/config --disable PHY_CIX_USB2
      ./scripts/config --disable PHY_CIX_USB3

      # --- Cadence USBSSP Platform and CIX Sky1 glue drivers ---
      ./scripts/config --disable USB_CDNSP
      ./scripts/config --disable USB_CDNSP_PCI
      ./scripts/config --disable USB_CDNSP_GADGET
      ./scripts/config --disable USB_CDNSP_HOST
      ./scripts/config --disable USB_CDNSP_SKY1

      # --- CIX ACPI USB scanning (route USB controllers to cdnsp-sky1) ---
      ./scripts/config --disable CIX_ACPI_USB_SCAN

      # --- USB Type-C ---
      ./scripts/config --enable TYPEC

      # --- TPM 2.0 ---
      ./scripts/config --enable TCG_TPM
      ./scripts/config --enable TCG_TIS
      ./scripts/config --enable TCG_TIS_CORE

      # --- SMMU bypass (prevent early display DMA faults/interrupt storm) ---
      ./scripts/config --disable ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT

      # --- Strict devmem for kernel security (userspace workaround removed) ---
      ./scripts/config --enable STRICT_DEVMEM
      ./scripts/config --enable IO_STRICT_DEVMEM

      # --- NVMe: force built-in for robust early-boot root mount ---
      ./scripts/config --enable BLK_DEV_NVME

      # --- SBSA Generic Watchdog: demote to module for blacklist effectiveness ---
      ./scripts/config --module ARM_SBSA_WATCHDOG

      # --- CIX DSP communications (HiFi5 DSP IPC/mailbox, prereq for future HDMI/DP audio) ---
      ./scripts/config --module CIX_DSP

      # --- NixOS filesystem and installer requirements ---
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

      # --- systemd support requirements ---
      ./scripts/config --enable CGROUPS
      ./scripts/config --enable AUTOFS_FS
      ./scripts/config --enable TMPFS_POSIX_ACL
      ./scripts/config --enable SECCOMP

      # --- USB Ethernet drivers (UGREEN CR111 and common USB-C docks) ---
      ./scripts/config --enable USB_NET_DRIVERS
      ./scripts/config --module USB_NET_AX88179_178A
      ./scripts/config --module USB_RTL8152
      ./scripts/config --module USB_USBNET
      ./scripts/config --module USB_NET_CDCETHER
      ./scripts/config --module USB_NET_CDC_NCM
      ./scripts/config --module USB_NET_RNDIS_HOST

      # --- Disable debug symbols to reduce build size and compile time ---
      ./scripts/config --disable DEBUG_INFO
      ./scripts/config --disable DEBUG_INFO_BTF
      ./scripts/config --disable DEBUG_INFO_DWARF5
      ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT

      # --- Disable irrelevant PCIe GPU drivers ---
      ./scripts/config --disable DRM_AMDGPU
      ./scripts/config --disable DRM_NOUVEAU
      ./scripts/config --disable DRM_RADEON

      # ── Phase 3: Validation gate ─────────────────────────────────────────
      # Verify critical CIX options survived configuration.
      # If any are missing, the build fails immediately rather than
      # producing a kernel with silently disabled drivers.
      echo "Validating kernel configuration..."
      MISSING=0
      for opt in \
        DRM_CIX DRM_LINLONDP DRM_TRILIN_DPSUB DRM_TRILIN_DP_CIX \
        DRM_TRILIN_CADENCE_PHY DRM_CIX_EDP_PANEL DRM_PANTHOR \
        PHY_CIX_USBDP \
        PWM_SKY1 CIX_DSP; do
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
