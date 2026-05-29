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
      make ARCH=arm64 defconfig

      # Explicitly enable Ext4 support for mounting the installer root filesystem
      ./scripts/config --enable EXT4_FS

      # Ensure critical Snapdragon features are built-in or enabled
      ./scripts/config --enable EFI_STUB
      ./scripts/config --enable DRM_MSM
      ./scripts/config --enable PINCTRL_X1E80100
      ./scripts/config --enable QCOM_COMMAND_DB
      ./scripts/config --enable QCOM_RPMH
      ./scripts/config --enable QCOM_RPMHPD

      # Disable problematic/unnecessary Ethernet vendors
      ./scripts/config --disable NET_VENDOR_TI
      ./scripts/config --disable NET_VENDOR_BROADCOM
      ./scripts/config --disable NET_VENDOR_INTEL
      ./scripts/config --disable NET_VENDOR_MARVELL
      ./scripts/config --disable NET_VENDOR_REALTEK
      ./scripts/config --disable NET_VENDOR_MICROCHIP
      ./scripts/config --disable NET_VENDOR_VIA
      ./scripts/config --disable NET_VENDOR_STMICRO
      ./scripts/config --disable NET_VENDOR_WIZNET
      ./scripts/config --disable NET_VENDOR_XILINX
      ./scripts/config --disable NET_VENDOR_SYNOPSYS
      ./scripts/config --disable NET_VENDOR_PENSANDO
      ./scripts/config --disable NET_VENDOR_RENESAS
      ./scripts/config --disable NET_VENDOR_CADENCE
      ./scripts/config --disable NET_VENDOR_NI
      ./scripts/config --disable NET_VENDOR_8390
      ./scripts/config --disable NET_VENDOR_SOLARFLARE
      ./scripts/config --disable NET_VENDOR_SOCIONEXT
      ./scripts/config --disable NET_VENDOR_WANGXUN

      # Explicitly re-enable Audio (often missing in generic builds)
      ./scripts/config --module SND_SOC_QCOM
      ./scripts/config --module SND_SOC_X1E80100
      ./scripts/config --module SND_SOC_LPASS_WSA_MACRO
      ./scripts/config --module SND_SOC_LPASS_VA_MACRO
      ./scripts/config --module SND_SOC_LPASS_RX_MACRO
      ./scripts/config --module SND_SOC_LPASS_TX_MACRO
      ./scripts/config --module SND_SOC_WSA884X
      ./scripts/config --module SND_SOC_WCD938X
      ./scripts/config --module SND_SOC_WCD_CLASSH

      # Camera (OV02C10 mentioned in Vinarskis patches)
      ./scripts/config --module VIDEO_OV02C10
      ./scripts/config --enable VIDEO_V4L2_SUBDEV_API

      # WiFi/BT co-existence and routing
      ./scripts/config --module ATH12K
      ./scripts/config --module QRTR_SMD
      ./scripts/config --module QRTR_MHI
      ./scripts/config --module QCOM_PD_MAPPER

      # Essential for ISO/Live media
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

      # System Control and Mailbox Built-ins
      ./scripts/config --enable QCOM_SCM
      ./scripts/config --enable QCOM_TZMEM
      ./scripts/config --enable QCOM_AOSS_QMP
      ./scripts/config --enable QCOM_IPCC
      ./scripts/config --enable QCOM_APCS_IPC
      ./scripts/config --enable ARM_SCMI_PROTOCOL
      ./scripts/config --enable ARM_SCMI_TRANSPORT_SMC
      ./scripts/config --enable ARM_SCMI_TRANSPORT_MAILBOX

      # Core Qualcomm Clocks and Interconnects (must be built-in)
      ./scripts/config --enable COMMON_CLK_QCOM
      ./scripts/config --enable CLK_X1E80100_GCC
      ./scripts/config --enable CLK_X1E80100_DISPCC
      ./scripts/config --enable CLK_X1E80100_GPUCC
      ./scripts/config --enable INTERCONNECT
      ./scripts/config --enable INTERCONNECT_QCOM
      ./scripts/config --enable INTERCONNECT_QCOM_X1E80100

      # Make sure crucial drivers aren't dropped by localmodconfig
      ./scripts/config --enable ARM_SMMU
      ./scripts/config --enable ARM_SMMU_V3
      ./scripts/config --enable USB_DWC3
      ./scripts/config --enable USB_DWC3_QCOM
      ./scripts/config --enable TYPEC
      ./scripts/config --enable TYPEC_UCSI
      ./scripts/config --enable UCSI_PMIC_GLINK
      ./scripts/config --enable PCIE_QCOM
      ./scripts/config --enable PHY_QCOM_QMP_USB
      ./scripts/config --enable PHY_QCOM_QMP_USBC
      ./scripts/config --enable PHY_QCOM_SNPS_EUSB2
      ./scripts/config --enable PHY_QCOM_EUSB2_REPEATER
      ./scripts/config --enable PHY_QCOM_QMP_COMBO
      ./scripts/config --enable QCOM_PMIC_GLINK
      ./scripts/config --enable TYPEC_QCOM_PMIC
      ./scripts/config --enable USB_UAS

      # Re-sync configuration
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
