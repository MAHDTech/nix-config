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
    version = "7.1.0-rc6-next-20260602";

    # Pull the absolute latest bleeding edge where Zenbook support lives
    src = pkgs.fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git";
      # Use the revision mentioned in the README as tested
      rev = "next-20260602";
      sha256 = "sha256-Ovr1EdeRUsv+lhsIJ/OWhAlhtmUJ6/pJ87TNJ1CKr4U=";
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

      echo "Fixing DTSI camera errors (camss/cci1/csiphy missing in this linux-next)..."
      # Comment out the camera sections that refer to missing labels
      sed -i '/&camss {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
      sed -i '/&cci1 {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
      sed -i '/&cci1_i2c1 {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
      sed -i '/&csiphy4 {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
    '';

    configurePhase = ''
      patchShebangs scripts/config

      # Use the Automated Hardware Profile
      cp ${./files/config/zenbook.defconfig} .config

      # Enable core TPM 2.0 drivers to prevent boot hangs and enable fTPM
      # TCG_TIS is x86 LPC-only — removed. CRB and FTPM_TEE cover ARM64/fTPM.
      ./scripts/config --enable TCG_CRB
      ./scripts/config --enable TCG_FTPM_TEE

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
      ./scripts/config --set-val DRM_MSM y
      ./scripts/config --set-val DRM_SCHED y

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

      # Enable MGLRU (Multi-Gen LRU) for memory optimization
      ./scripts/config --enable LRU_GEN
      ./scripts/config --enable LRU_GEN_ENABLED

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
      modDirVersion = "7.1.0-rc6-next-20260602";
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
