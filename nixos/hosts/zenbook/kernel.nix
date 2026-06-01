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
      ./scripts/config --enable DRM_MSM_DPU
      ./scripts/config --enable DRM_MSM_DP
      ./scripts/config --enable DRM_MSM_DSI
      ./scripts/config --module DRM_PANEL_EDP
      ./scripts/config --module DRM_PANEL_SIMPLE
      ./scripts/config --enable BACKLIGHT_CLASS_DEVICE
      ./scripts/config --enable DRM_DISPLAY_DSC_HELPER
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

      # ── Audio (SoundWire bus MUST come before machine driver) ──
      ./scripts/config --module SOUNDWIRE
      ./scripts/config --module SOUNDWIRE_QCOM
      ./scripts/config --module QCOM_APR
      ./scripts/config --module SND_SOC_QCOM
      ./scripts/config --module SND_SOC_X1E80100
      ./scripts/config --module SND_SOC_LPASS_WSA_MACRO
      ./scripts/config --module SND_SOC_LPASS_VA_MACRO
      ./scripts/config --module SND_SOC_LPASS_RX_MACRO
      ./scripts/config --module SND_SOC_LPASS_TX_MACRO
      ./scripts/config --module SND_SOC_WSA884X
      ./scripts/config --module SND_SOC_WCD938X_SDW

      # ── Camera (OV02C10 mentioned in Vinarskis patches) ──
      ./scripts/config --module VIDEO_OV02C10
      ./scripts/config --enable VIDEO_V4L2_SUBDEV_API
      ./scripts/config --module VIDEO_QCOM_CAMSS

      # ── WiFi (WCN7850 via ath12k) ──
      ./scripts/config --module ATH12K
      ./scripts/config --module ATH12K_PCI
      ./scripts/config --module CFG80211
      ./scripts/config --enable CFG80211_DEFAULT_PS
      ./scripts/config --module MAC80211
      ./scripts/config --enable MAC80211_LEDS
      ./scripts/config --module RFKILL
      ./scripts/config --module RFKILL_GPIO
      ./scripts/config --module QRTR_SMD
      ./scripts/config --module QRTR_MHI
      ./scripts/config --module QCOM_PD_MAPPER

      # ── Bluetooth (WCN7850-BT via hci_uart/btqca) ──
      ./scripts/config --module BT
      ./scripts/config --module BT_HCIUART
      ./scripts/config --set-val BT_HCIUART_SERDEV y
      ./scripts/config --set-val BT_HCIUART_QCA y
      ./scripts/config --module BT_HCIBTUSB
      ./scripts/config --module BT_RFCOMM
      ./scripts/config --set-val BT_RFCOMM_TTY y
      ./scripts/config --module BT_BNEP
      ./scripts/config --set-val BT_BNEP_MC_FILTER y
      ./scripts/config --set-val BT_BNEP_PROTO_FILTER y
      ./scripts/config --module BT_HIDP
      ./scripts/config --enable BT_LE
      ./scripts/config --enable BT_LEDS

      # ── WCN7850 Power Sequencing (BT + WiFi shared PMU) ──
      ./scripts/config --module POWER_SEQUENCING_QCOM_WCN
      ./scripts/config --module POWER_SEQUENCING_PCIE_M2

      # ── Hardware video decoder (Qualcomm Iris V4L2) ──
      ./scripts/config --module VIDEO_QCOM_IRIS
      ./scripts/config --enable MEDIA_SUPPORT

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

      # System Control, Security, and Mailbox Built-ins
      ./scripts/config --enable QCOM_SCM
      ./scripts/config --enable QCOM_TZMEM
      ./scripts/config --enable QCOM_TZMEM_MODE_SHMBRIDGE
      ./scripts/config --enable QCOM_QSEECOM
      ./scripts/config --enable QCOM_QSEECOM_UEFISECAPP
      ./scripts/config --module QCOM_FASTRPC
      ./scripts/config --module RPMSG_CHAR
      ./scripts/config --module RPMSG_CTRL
      ./scripts/config --module QCOM_Q6V5_ADSP
      ./scripts/config --module LEDS_QCOM_LPG
      ./scripts/config --enable QCOM_AOSS_QMP
      ./scripts/config --enable QCOM_IPCC
      ./scripts/config --enable QCOM_APCS_IPC
      ./scripts/config --enable QCOM_PDC
      ./scripts/config --enable QCOM_LLCC
      ./scripts/config --enable QCOM_GENI_SE
      ./scripts/config --enable QCOM_CLK_RPMH
      ./scripts/config --enable ARM_QCOM_CPUFREQ_HW
      ./scripts/config --enable QCOM_TSENS
      ./scripts/config --module QCOM_SPMI_TEMP_ALARM
      ./scripts/config --module QCOM_ICC_BWMON
      ./scripts/config --enable REMOTEPROC
      ./scripts/config --module QCOM_Q6V5_PAS
      ./scripts/config --enable ARM_SCMI_PROTOCOL
      ./scripts/config --enable ARM_SCMI_TRANSPORT_SMC
      ./scripts/config --enable ARM_SCMI_TRANSPORT_MAILBOX
      ./scripts/config --set-val MAILBOX y
      ./scripts/config --set-val QCOM_SMEM y
      ./scripts/config --set-val QCOM_SMSM y
      ./scripts/config --set-val QCOM_SMEM_STATE y
      ./scripts/config --set-val QCOM_SMP2P y
      ./scripts/config --set-val RPMSG_QCOM_GLINK y
      ./scripts/config --set-val RPMSG_QCOM_GLINK_SMEM y
      ./scripts/config --set-val QCOM_PDR_HELPERS y
      ./scripts/config --set-val QCOM_QMI_HELPERS y
      ./scripts/config --set-val QCOM_CPUCP_MBOX y

      # Keyboard and Input Bus Built-ins
      ./scripts/config --set-val I2C_QCOM_GENI y
      ./scripts/config --set-val I2C_HID y
      ./scripts/config --set-val I2C_HID_CORE y
      ./scripts/config --set-val I2C_HID_OF y
      ./scripts/config --set-val I2C_HID_OF_ELAN y
      ./scripts/config --set-val I2C_HID_OF_GOODIX y
      ./scripts/config --module HID_GENERIC
      ./scripts/config --module HID_MULTITOUCH
      ./scripts/config --set-val INPUT_EVDEV y

      # Core Qualcomm Clocks and Interconnects (must be built-in)
      ./scripts/config --enable COMMON_CLK_QCOM
      ./scripts/config --enable CLK_X1E80100_GCC
      ./scripts/config --enable CLK_X1E80100_DISPCC
      ./scripts/config --enable CLK_X1E80100_GPUCC
      ./scripts/config --enable INTERCONNECT
      ./scripts/config --enable INTERCONNECT_QCOM
      ./scripts/config --enable INTERCONNECT_QCOM_X1E80100

      # IOMMU — Qualcomm-specific SMMU + lazy TLB for performance
      ./scripts/config --enable ARM_SMMU
      ./scripts/config --enable ARM_SMMU_V3
      ./scripts/config --enable ARM_SMMU_QCOM
      ./scripts/config --enable IOMMU_DEFAULT_DMA_LAZY

      # USB Core — explicitly enable full XHCI stack
      ./scripts/config --enable USB_SUPPORT
      ./scripts/config --enable USB
      ./scripts/config --enable USB_ANNOUNCE_NEW_DEVICES
      ./scripts/config --enable USB_XHCI_HCD
      ./scripts/config --enable USB_XHCI_PCI
      ./scripts/config --enable USB_XHCI_PLATFORM
      ./scripts/config --enable USBHID
      ./scripts/config --enable USB_DWC3
      ./scripts/config --enable USB_DWC3_QCOM
      ./scripts/config --enable USB_DWC3_DUAL_ROLE
      ./scripts/config --enable USB_GADGET
      ./scripts/config --enable USB_STORAGE
      ./scripts/config --enable USB_UAS
      ./scripts/config --set-val USB_ROLE_SWITCH y

      # USB Ethernet Drivers
      ./scripts/config --enable NETDEVICES
      ./scripts/config --enable USB_NET_DRIVERS
      ./scripts/config --module USB_NET_AX88179_178A
      ./scripts/config --module USB_RTL8152
      ./scripts/config --module USB_USBNET
      ./scripts/config --module USB_NET_CDCETHER
      ./scripts/config --module USB_NET_CDC_NCM
      ./scripts/config --module USB_NET_RNDIS_HOST

      # Type-C — UCSI, PMIC GLINK, alt modes, retimers
      ./scripts/config --set-val TYPEC y
      ./scripts/config --set-val TYPEC_UCSI y
      ./scripts/config --set-val UCSI_PMIC_GLINK y
      ./scripts/config --set-val QCOM_PMIC_GLINK y
      ./scripts/config --set-val QCOM_PMIC_GLINK_ALTMODE y
      ./scripts/config --set-val TYPEC_DP_ALTMODE y
      ./scripts/config --set-val TYPEC_MUX_PS883X y
      ./scripts/config --module TYPEC_MUX_NB7VPQ904M
      ./scripts/config --module TYPEC_MUX_PTN36502

      # PCIe
      ./scripts/config --set-val PHY_QCOM_QMP y
      ./scripts/config --set-val PHY_QCOM_QMP_PCIE y
      ./scripts/config --set-val PCIE_QCOM y

      # USB PHYs — eUSB2, QMP combo, PTN3222 redriver
      ./scripts/config --set-val PHY_QCOM_QMP_USB y
      ./scripts/config --set-val PHY_SNPS_EUSB2 y
      ./scripts/config --set-val PHY_QCOM_USB_SNPS_FEMTO_V2 y
      ./scripts/config --set-val PHY_QCOM_QUSB2 y
      ./scripts/config --set-val PHY_QCOM_EUSB2_REPEATER y
      ./scripts/config --set-val PHY_QCOM_QMP_COMBO y
      # eUSB2-to-USB2 redriver — required for DWC3 USB to probe on x1e80100
      ./scripts/config --set-val PHY_NXP_PTN3222 y

      # ── Power/Battery ──
      ./scripts/config --enable POWER_SUPPLY
      ./scripts/config --module BATTERY_QCOM_BATTMGR

      # ── Suspend/Resume & Power Efficiency ──
      ./scripts/config --enable WQ_POWER_EFFICIENT_DEFAULT

      # ── PMIC/Regulators (voltage rail management) ──
      ./scripts/config --enable REGULATOR_QCOM_RPMH
      ./scripts/config --enable REGULATOR_QCOM_SPMI
      ./scripts/config --enable MFD_SPMI_PMIC
      ./scripts/config --enable SPMI_MSM_PMIC_ARB
      ./scripts/config --enable INPUT_PM8941_PWRKEY
      ./scripts/config --module POWER_RESET_QCOM_PON

      # ── Watchdog & RTC ──
      ./scripts/config --module QCOM_WDT
      ./scripts/config --module RTC_DRV_PM8XXX
      ./scripts/config --module QCOM_STATS

      # ── Sensors (HID IIO — accelerometer, ALS, gyroscope) ──
      ./scripts/config --module HID_SENSOR_HUB
      ./scripts/config --module HID_SENSOR_IIO_COMMON
      ./scripts/config --module HID_SENSOR_ACCEL_3D
      ./scripts/config --module HID_SENSOR_ALS
      ./scripts/config --module HID_SENSOR_GYRO_3D
      ./scripts/config --enable IIO

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
