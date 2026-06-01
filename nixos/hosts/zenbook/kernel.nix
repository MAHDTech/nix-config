{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # The actual kernel build
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "latest-zenbook";
    # Set version to match what linux-next reports to avoid mismatch
    version = "7.1.0-rc5-next-20260528";

    # Pull the absolute latest bleeding edge where Zenbook support lives
    src = pkgs.fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git";
      # Use the revision mentioned in the README as tested
      rev = "next-20260528";
      sha256 = "sha256-86TmX6XmHk0pLorcK/ZQ5AHsGj/c6mKQlLdT0DX2ltA=";
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
      echo "Applying Zenbook patches from ${inputs.zenbook-linux}..."
      for patch in ${inputs.zenbook-linux}/*.patch; do
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

      # Force display and panel drivers as built-ins (=y) to ensure framebuffer
      # output is available from the very first kernel stage. Using --set-val y
      # prevents olddefconfig from demoting them to modules (=m).
      ./scripts/config --set-val DRM_SIMPLEDRM y
      ./scripts/config --set-val DRM_PANEL_EDP y
      ./scripts/config --set-val DRM_PANEL_SIMPLE y
      ./scripts/config --set-val DRM_PANEL_SAMSUNG_ATNA33XC20 y
      ./scripts/config --enable DRM_MSM
      ./scripts/config --enable DRM_SCHED

      # WiFi: alexVinarskis patch set reorganises ath12k into a wifi7/ subdirectory.
      # The PCIe bus module is ath12k_wifi7_pci (not ath12k_pci).
      # Enable the parent split-driver config symbol.
      ./scripts/config --module ATH12K_WIFI7_PCI

      # USB-C: UCSI over Qualcomm PMIC glink — required for PD negotiation and
      # DisplayPort alt-mode on the USB-C ports.
      # Note: kernel config symbol is UCSI_PMIC_GLINK (not UCSI_GLINK); module name is ucsi_glink.
      # Already =m in the defconfig; this ensures it survives any future defconfig regeneration.
      ./scripts/config --module UCSI_PMIC_GLINK

      # SPI via GENI SE — needed for some on-board SPI peripherals
      ./scripts/config --module SPI_QCOM_GENI

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
      modDirVersion = "7.1.0-rc5-next-20260528";
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
