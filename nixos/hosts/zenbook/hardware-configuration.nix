{ lib, pkgs, inputs, ... }:
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];

    # Use the specific kernel tree for Zenbook A14 support
    kernelPackages = let
      # We use linux_latest to get the base kernel for versioning helper functions
      baseKernel = pkgs.linux_latest;
      
      # The actual kernel build
      kernelBuild = pkgs.stdenv.mkDerivation rec {
        pname = "latest-zenbook";
        # Set version to match what linux-next reports to avoid mismatch
        version = "6.19.0-rc4-next-20260109"; 
        
        # Pull the absolute latest bleeding edge where Zenbook support lives
        src = pkgs.fetchgit {
          url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git";
          # Use the revision mentioned in the README as tested
          rev = "next-20260109"; 
          sha256 = "sha256-wCsWxGnKycbXFY0PEPUKnMFsy6pQ+SaEVDcOkySIzac=";
        };
        
        nativeBuildInputs = with pkgs; [
          perl bc nettools openssl rsync gmp libmpc mpfr 
          util-linux elfutils binutils flex bison pahole zstd gcc gnumake
          python3
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

        # satisfy the kernel modules expectations
        passthru = {
          modDirVersion = version;
          config = { 
            isEnabled = _: true; 
            isYes = _: true;
            isNo = _: false;
            isModule = _: false;
          };
          kernelOlder = v: lib.versionOlder version v;
          kernelAtLeast = v: lib.versionAtLeast version v;
          inherit version;
          override = _: kernelBuild;
          overrideAttrs = _: kernelBuild;
        };

        configurePhase = ''
          patchShebangs scripts/config
          make ARCH=arm64 defconfig
          
          echo "Applying opt-in configuration via localmodconfig..."
          LSMOD=${./lsmod.txt} make ARCH=arm64 localmodconfig
          
          # Ensure critical Snapdragon features are built-in or enabled
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
          make ARCH=arm64 modules_install INSTALL_MOD_PATH=$out
          
          # Delete dangling symlinks that point to the build directory
          rm -rf $out/lib/modules/*/build
          rm -rf $out/lib/modules/*/source
        '';
      };
    in lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd = {
      includeDefaultModules = false;
      allowMissingModules = true;
      availableKernelModules = [
        "nvme" "usb_storage" "usbhid" "xhci_pci" "uas" "sd_mod"
        "arm_smmu" "qcom_geni_se" "qcom_smd_regulator" "qcom_spmi_regulator"
        "ath12k" "msm" "i2c_hid_of" "i2c_hid" "hid_multitouch"
        "snd_soc_x1e80100" "qcom_q6v5_pas" "qcom_sysmon" "qrtr_smd"
        # Plan B: USB Tethering drivers
        "usbnet" "cdc_ether" "cdc_ncm" "cdc_mbim" "rndis_host"
      ];
      kernelModules = [ "kvm" ];
    };

    kernelParams = [
      "clk_ignore_unused" "pd_ignore_unused"
      "console=ttyAMA0,115200n8" "console=tty0"
      "earlyprintk" "cma=128M" "video=efifb" "fbcon=map:0"
      "arm64.nopauth"
    ];

    # Modern boot management
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = lib.mkForce "/boot";
      };
    };
  };

  hardware = {
    graphics.enable = true;
    deviceTree = {
      enable = true;
      # The alexVinarskis kernel builds this DTB from its own DTS sources.
      name = "qcom/x1e80100-asus-zenbook-ux3407.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [ (import ./firmware.nix { inherit pkgs; }) ];
  };

  # Audio (Pull UCM files from the patched kernel tree)
  environment.etc."alsa/ucm2".source = "${inputs.zenbook-linux}/ucm2";

  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
