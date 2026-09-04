{
  pkgs,
  lib,
  ...
}:

let
  kernelVersion = "7.2.0-rc5";

  kernelSrc = pkgs.fetchurl {
    url = "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-7.2-rc5.tar.gz";
    sha256 = "07nm1mdpx9nqxh8bin0isnl2b7460if5g7ssy4krkj2vbhjbzrcb";
  };

  # Shared patch script — no out-of-tree patches are required for 7.2-rc5
  # since all ASUS Zenbook A14 DTS and audio binding patches are merged upstream.
  patchScript = ''
    echo "No out-of-tree patches required for 7.2.0-rc5 (ASUS Zenbook A14 DTS merged upstream)."
  '';

  # Shared config generation script — runs scripts/config + make olddefconfig.
  # Produces an identical .config in both the config-only and full build derivations.
  configScript = ''
    patchShebangs scripts/config

    # Use the Automated Hardware Profile
    cp ${../files/config/zenbook.defconfig} .config
    chmod +w .config

    # Disable irrelevant architectures to drastically reduce compile time
    ./scripts/config --disable ARCH_EXYNOS
    ./scripts/config --disable ARCH_TEGRA
    ./scripts/config --disable ARCH_MEDIATEK
    ./scripts/config --disable ARCH_ROCKCHIP

    # Qualcomm TLMM pin controller — CRITICAL for boot.
    # The defconfig lacks PINCTRL_MSM which is the parent Kconfig for all QCOM
    # TLMM drivers. Without PINCTRL_X1E80100 no GPIOs are configured and the
    # system gets a black screen.
    ./scripts/config --enable PINCTRL_MSM
    ./scripts/config --enable PINCTRL_X1E80100

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

    # SCMI Powercap: enforces power budget limits through firmware.
    # This is the Linux equivalent of the Windows Power Engine Plug-in (PEP).
    # Ubuntu's linux-qcom-x1e kernel has this enabled — it was MISSING from our config
    # and is the most likely root cause fix for PMIC overcurrent resets.
    ./scripts/config --enable POWERCAP
    ./scripts/config --enable ARM_SCMI_POWERCAP

    # SCMI power control and debugfs — matches Ubuntu's linux-qcom-x1e kernel
    ./scripts/config --enable ARM_SCMI_POWER_CONTROL
    ./scripts/config --enable ARM_SCMI_NEED_DEBUGFS
    ./scripts/config --enable ARM_SCMI_QUIRKS

    # Qualcomm Subsystem Power Manager — manages SoC low-power states.
    # Built-in (=y) in Ubuntu's kernel. Required for proper power state transitions.
    ./scripts/config --enable QCOM_SPM

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

    # WiFi: defconfig already has ATH12K=m
    # USB-C: UCSI over Qualcomm PMIC glink — required for PD negotiation and DisplayPort alt-mode
    ./scripts/config --module UCSI_PMIC_GLINK

    # SPI via GENI SE — needed for some on-board SPI peripherals
    ./scripts/config --module SPI_QCOM_GENI

    # Enable USB4/Thunderbolt support for docking stations
    ./scripts/config --module USB4
    ./scripts/config --module USB4_NET
    ./scripts/config --module TYPEC_DP_ALTMODE
    ./scripts/config --module TYPEC_TBT_ALTMODE

    # Audio amplifier codecs for Zenbook speakers and SoundWire
    ./scripts/config --module SND_SOC_WSA884X
    ./scripts/config --module SND_SOC_WCD938X
    ./scripts/config --module SND_SOC_WCD938X_SDW
    ./scripts/config --module SOUNDWIRE_QCOM

    # Enable MGLRU (Multi-Gen LRU) for memory optimization
    ./scripts/config --enable LRU_GEN
    ./scripts/config --enable LRU_GEN_ENABLED

    # zram: compressed RAM swap — required by NixOS zramSwap module
    ./scripts/config --module ZRAM
    ./scripts/config --enable ZRAM_BACKEND_ZSTD
    ./scripts/config --enable ZRAM_DEF_COMP_ZSTD

    # AppArmor: mandatory access control — required by security.apparmor.enable = true
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
    ./scripts/config --enable CRYPTO_ZSTD

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

    # Enable firmware loader compression support for compressed firmware files on NixOS
    ./scripts/config --enable FW_LOADER_COMPRESS
    ./scripts/config --enable FW_LOADER_COMPRESS_ZSTD

    # Re-sync configuration against the active kernel tree
    make ARCH=arm64 olddefconfig
  '';

  # Minimal nativeBuildInputs needed for config generation (Kconfig parsing).
  configBuildInputs = with pkgs; [
    buildPackages.stdenv.cc
    bc
    bison
    flex
    gnumake
    perl
    python3
  ];

  # Full nativeBuildInputs for the actual kernel compilation.
  kernelBuildInputs = with pkgs; [
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

  # Stage 1: Config-only derivation
  generatedConfig = pkgs.stdenv.mkDerivation {
    name = "zenbook-kernel-config-${kernelVersion}";
    src = kernelSrc;
    nativeBuildInputs = configBuildInputs;
    phases = [
      "unpackPhase"
      "patchPhase"
      "buildPhase"
      "installPhase"
    ];
    patchPhase = patchScript;
    buildPhase = configScript;
    installPhase = ''
      cp .config $out
    '';
  };

  configText = builtins.readFile generatedConfig;
  configLines = builtins.filter (l: l != "") (lib.splitString "\n" configText);
  configParsed =
    let
      parseOne =
        line:
        let
          m = builtins.match "CONFIG_([A-Za-z0-9_]+)=(.*)" line;
        in
        if m != null then
          {
            name = builtins.elemAt m 0;
            value = builtins.elemAt m 1;
          }
        else
          null;
      parsed = builtins.filter (x: x != null) (map parseOne configLines);
    in
    builtins.listToAttrs parsed;

  kernelConfig = {
    isEnabled =
      option:
      let
        val = configParsed.${option} or "";
      in
      val == "y" || val == "m";
    isYes =
      option:
      let
        val = configParsed.${option} or "";
      in
      val == "y";
    isNo = option: !(builtins.hasAttr option configParsed);
    isModule =
      option:
      let
        val = configParsed.${option} or "";
      in
      val == "m";
    isSet = option: builtins.hasAttr option configParsed;
  };

  # Stage 2: The actual kernel build
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "mainline-zenbook";
    version = kernelVersion;

    enableParallelBuilding = true;

    src = kernelSrc;

    nativeBuildInputs = kernelBuildInputs;

    buildInputs = with pkgs; [
      zlib
      elfutils
    ];

    prePatch = patchScript;

    configurePhase = configScript;

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

    passthru = rec {
      modDirVersion = kernelVersion;
      version = modDirVersion;
      dev = kernelBuild;
      moduleBuildDependencies = [ ];
      configfile = generatedConfig;
      config = kernelConfig;
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
