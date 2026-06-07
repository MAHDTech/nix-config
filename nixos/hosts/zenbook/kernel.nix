{
  pkgs,
  lib,
  ...
}:

let
  # The actual kernel build
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "latest-zenbook";
    # Set version to match what linux-next reports to avoid mismatch
    version = "7.1.0-rc6-next-20260605";

    enableParallelBuilding = true;

    # Pull the absolute latest bleeding edge where Zenbook support lives
    src = pkgs.fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git";
      rev = "next-20260605";
      sha256 = "sha256-tkBYk1CSWonH8P2T3+SVX6mJF4RuTU4+35ZD42ff0Xw=";
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

    # Apply the patches from the input.
    prePatch = ''
      echo "Applying local Zenbook patches..."
      for patch in ${./files/patches}/*.patch; do
        echo "Applying $patch"
        patch -p1 < "$patch"
      done

      echo "Patching DRM_MSM Kconfig to select DRM_SYNCOBJ..."
      sed -i '/^config DRM_MSM$/a \\tselect DRM_SYNCOBJ\n\tselect DRM_SYNCOBJ_TIMELINE_EXPORT' drivers/gpu/drm/msm/Kconfig
    '';

    configurePhase = ''
      patchShebangs scripts/config

      # Use the Automated Hardware Profile
      cp ${./files/config/zenbook.defconfig} .config
      chmod +w .config

      # Disable irrelevant architectures to drastically reduce compile time
      ./scripts/config --disable ARCH_EXYNOS
      ./scripts/config --disable ARCH_TEGRA
      ./scripts/config --disable ARCH_MEDIATEK
      ./scripts/config --disable ARCH_ROCKCHIP

      # Restore critical Qualcomm inter-processor communication & mailbox drivers
      # which are required for boot but got disabled due to cascading defconfig dependencies
      ./scripts/config --enable MAILBOX
      ./scripts/config --enable QCOM_CPUCP_MBOX
      ./scripts/config --enable QCOM_AOSS_QMP
      ./scripts/config --enable QCOM_APCS_IPC
      ./scripts/config --enable QCOM_IPCC
      ./scripts/config --enable QCOM_MPM
      ./scripts/config --enable QCOM_SMEM_STATE
      ./scripts/config --enable QCOM_SMP2P
      ./scripts/config --enable QCOM_SMSM
      ./scripts/config --enable RPMSG_QCOM_GLINK
      ./scripts/config --enable RPMSG_QCOM_GLINK_RPM
      ./scripts/config --enable RPMSG_QCOM_GLINK_SMEM
      ./scripts/config --enable RPMSG_QCOM_SMD

      # Enable core TPM 2.0 drivers to prevent boot hangs and enable fTPM
      # TCG_TIS is x86 LPC-only — removed. CRB and FTPM_TEE cover ARM64/fTPM.
      ./scripts/config --enable TCG_CRB
      ./scripts/config --enable TCG_FTPM_TEE
      # Enable core SCMI drivers required for Snapdragon X Elite clocks/regulators/power/CPUs
      ./scripts/config --enable ARM_SCMI_PROTOCOL
      ./scripts/config --enable ARM_SCMI_TRANSPORT_MAILBOX
      ./scripts/config --enable ARM_SCMI_TRANSPORT_SMC
      ./scripts/config --enable ARM_SCMI_TRANSPORT_OPTEE
      ./scripts/config --enable SENSORS_ARM_SCMI
      ./scripts/config --enable REGULATOR_ARM_SCMI
      ./scripts/config --enable COMMON_CLK_SCMI
      ./scripts/config --enable ARM_SCMI_CPUFREQ
      ./scripts/config --enable ARM_SCMI_POWER_DOMAIN
      ./scripts/config --enable ARM_SCMI_PERF_DOMAIN
      ./scripts/config --enable RESET_SCMI

      # Enable PSTORE_RAM (ramoops) for crash debugging
      ./scripts/config --enable PSTORE
      ./scripts/config --enable PSTORE_RAM
      ./scripts/config --enable PSTORE_CONSOLE
      ./scripts/config --enable PSTORE_PMSG

      # DRM: force parent DRM subsystem =y first. With DRM=m (default), olddefconfig
      # cannot promote any child (DRM_PANEL_EDP, DRM_SIMPLEDRM, etc.) to =y since
      # built-in drivers cannot depend on a loadable module. DRM=y allows all panel
      # and display drivers to be compiled in for early framebuffer availability.
      ./scripts/config --set-val DRM y
      ./scripts/config --set-val DRM_KMS_HELPER y
      ./scripts/config --set-val DRM_SIMPLEDRM y
      ./scripts/config --set-val DRM_PANEL_EDP y
      ./scripts/config --set-val DRM_PANEL_SIMPLE y
      ./scripts/config --set-val DRM_PANEL_SAMSUNG_ATNA33XC20 y
      ./scripts/config --module DRM_MSM
      ./scripts/config --set-val DRM_SCHED y

      # DRM syncobj: required by Turnip (freedreno Vulkan driver) for GPU command
      # synchronization. Without this, Vulkan renders one frame then hangs because
      # the driver cannot signal/wait on submission fences between frames.
      ./scripts/config --enable DRM_SYNCOBJ
      ./scripts/config --enable DRM_SYNCOBJ_TIMELINE_EXPORT

      # Qualcomm Limits Management Hardware (LMH): provides hardware-level
      # overcurrent and thermal throttling for CPU/GPU. Without this, sustained
      # CPU load (e.g. kernel compilation) causes PMIC overcurrent hard resets.
      # The hardware can throttle independently via TrustZone firmware, but the
      # kernel driver is needed to properly configure thresholds and interrupts.
      ./scripts/config --enable QCOM_LMH

      # WiFi: alexVinarskis patch set reorganises ath12k into a wifi7/ subdirectory.
      # The kernel config symbol is still CONFIG_ATH12K (covers both PCI and AHB) — no
      # separate ATH12K_WIFI7_PCI kernel config symbol exists. The on-disk module name
      # is ath12k_wifi7_pci. CONFIG_ATH12K=m in the defconfig is sufficient.
      # (No scripts/config call needed here — defconfig already has ATH12K=m)

      # USB-C: UCSI over Qualcomm PMIC glink — required for PD negotiation and
      # DisplayPort alt-mode on the USB-C ports.
      # Note: kernel config symbol is UCSI_PMIC_GLINK (not UCSI_GLINK); module name is ucsi_glink.
      # Already =m in the defconfig; this ensures it survives any future defconfig regeneration.
      ./scripts/config --module UCSI_PMIC_GLINK

      # SPI via GENI SE — needed for some on-board SPI peripherals
      ./scripts/config --module SPI_QCOM_GENI

      # Enable USB4/Thunderbolt support for docking stations
      ./scripts/config --module USB4
      ./scripts/config --module TYPEC_DP_ALTMODE
      ./scripts/config --module TYPEC_TBT_ALTMODE

      # Audio amplifier codecs for Zenbook speakers
      ./scripts/config --module SND_SOC_WSA884X

      # Enable MGLRU (Multi-Gen LRU) for memory optimization
      ./scripts/config --enable LRU_GEN
      ./scripts/config --enable LRU_GEN_ENABLED

      # zram: compressed RAM swap — required by NixOS zramSwap module
      # Without this, zramSwap.enable = true silently does nothing
      ./scripts/config --module ZRAM
      ./scripts/config --enable ZRAM_DEF_COMP_ZSTD

      # AppArmor: mandatory access control — required by security.apparmor.enable = true
      # Without this, NixOS enables AppArmor userspace but the kernel has no LSM support
      ./scripts/config --enable SECURITY_APPARMOR
      ./scripts/config --enable DEFAULT_SECURITY_APPARMOR

      # Enable standard kernel Crypto APIs required by iwd for WiFi authentication
      ./scripts/config --enable CRYPTO_USER_API_HASH
      ./scripts/config --enable CRYPTO_USER_API_SKCIPHER
      ./scripts/config --enable KEY_DH_OPERATIONS
      ./scripts/config --enable CRYPTO_ECB
      ./scripts/config --enable CRYPTO_MD5
      ./scripts/config --enable CRYPTO_CBC
      ./scripts/config --enable CRYPTO_SHA256
      ./scripts/config --enable CRYPTO_AES
      ./scripts/config --enable CRYPTO_DES
      ./scripts/config --enable CRYPTO_CMAC
      ./scripts/config --enable CRYPTO_HMAC
      ./scripts/config --enable CRYPTO_SHA512
      ./scripts/config --enable CRYPTO_SHA1

      # Enable Netfilter and nftables kernel support for firewall
      ./scripts/config --enable NF_TABLES
      ./scripts/config --enable NF_TABLES_INET
      ./scripts/config --enable NF_TABLES_NETDEV
      ./scripts/config --enable NFT_CT
      ./scripts/config --enable NFT_LOG
      ./scripts/config --enable NFT_LIMIT
      ./scripts/config --enable NFT_MASQ
      ./scripts/config --enable NFT_REDIR
      ./scripts/config --enable NFT_REJECT
      ./scripts/config --enable NFT_COMPAT
      ./scripts/config --enable NF_TABLES_IPV4
      ./scripts/config --enable NF_TABLES_IPV6
      ./scripts/config --enable NFT_FIB
      ./scripts/config --enable NFT_FIB_INET
      ./scripts/config --enable NFT_FIB_IPV4
      ./scripts/config --enable NFT_FIB_IPV6
      ./scripts/config --enable NFT_NAT
      ./scripts/config --enable NF_NAT
      ./scripts/config --enable NF_CONNTRACK

      # Enable netconsole for remote crash capture over UDP
      ./scripts/config --module NETCONSOLE
      ./scripts/config --enable NETCONSOLE_DYNAMIC

      # Enable pstore-blk for NVMe-backed crash storage (future use)
      ./scripts/config --enable PSTORE_BLK
      ./scripts/config --set-val PSTORE_BLK_KMSG_SIZE 64
      ./scripts/config --set-val PSTORE_BLK_CONSOLE_SIZE 64
      ./scripts/config --set-val PSTORE_BLK_PMSG_SIZE 64
      ./scripts/config --set-val PSTORE_BLK_MAX_REASON 2

      # Enable firmware loader compression support for compressed firmware files on NixOS
      ./scripts/config --enable FW_LOADER_COMPRESS
      ./scripts/config --enable FW_LOADER_COMPRESS_ZSTD

      # Re-sync configuration against the active kernel tree
      make ARCH=arm64 olddefconfig
    '';

    buildPhase = ''
      make ARCH=arm64 -j$NIX_BUILD_CORES
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp .config $out/config
      make ARCH=arm64 modules_install INSTALL_MOD_PATH=$out
      make ARCH=arm64 dtbs_install INSTALL_DTBS_PATH=$out/dtbs

      # Delete dangling symlinks that point to the build directory
      rm -rf $out/lib/modules/*/build
      rm -rf $out/lib/modules/*/source
    '';

    # satisfy the kernel modules expectations
    passthru = rec {
      modDirVersion = "7.1.0-rc6-next-20260605";
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
