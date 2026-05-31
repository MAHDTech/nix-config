{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ ];

  boot = {
    supportedFilesystems = lib.mkDefault [
      "vfat"
      "btrfs"
    ];

    # Use the specific kernel tree for Zenbook A14 support
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ./kernel.nix { inherit inputs; };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd = {
      includeDefaultModules = false;
      allowMissingModules = true;
      # Use systemd-based initrd for proper ARM64 hardware initialization and
      # device dependency resolution (proven critical for Snapdragon X Elite)
      systemd.enable = true;
      availableKernelModules = [
        # NVMe / Storage & Bus Controllers
        "nvme"
        "usb_storage"
        "usbhid"
        "hid_generic"
        "uas"
        "sd_mod"
        "xhci_pci"
        "xhci_hcd"
        "xhci_plat_hcd"
        "dwc3"
        "dwc3_qcom"
        "pcie_qcom"
        "arm_smmu"
        "qcom_smd_regulator"
        "qcom_spmi_regulator"
        "qcom_geni_se"

        # USB transceivers, PHYs, and PMIC power state mapping (required for USB ports)
        "phy_qcom_qmp_usb"
        "phy_snps_eusb2"
        "phy_qcom_eusb2_repeater"
        "phy_qcom_qmp_combo"
        "ptn3222"
        "pmic_glink"
        "qcom_pmic_glink"
        "qcom_pmic_typec"
        "typec_mux_ps883x"

        # Keyboard and Touchpad (I2C HID — critical for built-in laptop input)
        "i2c_hid"
        "i2c_hid_of"
        "i2c_qcom_geni"
        "hid_multitouch"
        "evdev"

        # Bluetooth (WCN7850-BT)
        "bluetooth"
        "btqca"
        "hci_uart"
        "bnep"
        "rfcomm"

        # WiFi/BT power sequencing
        "pwrseq_qcom_wcn"

        # Filesystem and Live Media Support
        "iso9660"
        "squashfs"
        "overlay"
        "loop"
        "btrfs"
        "ext4"
      ];
      kernelModules = [ ];

      # Load crucial platform firmware directly in stage 1 to prevent driver crashes
      extraFirmwarePaths = [
        "qcom"
        "ath12k"
      ];
    };

    kernelParams = [
      "clk_ignore_unused"
      "pd_ignore_unused"
      "regulator_ignore_unused"
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "earlyprintk"
      "cma=128M"
      "video=efifb"
      "fbcon=map:0"
      "arm64.nopauth"
      "pcie_aspm=off"
      "efi=noruntime"
    ];

    # Speaker safety interlock — required by snd-soc-x1e80100 driver
    extraModprobeConfig = ''
      options snd-soc-x1e80100 i_accept_the_danger=1
    '';

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
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [
      (pkgs.callPackage ./firmware.nix { })
      (pkgs.runCommand "zenbook-initrd-firmware" { } ''
        mkdir -p $out/lib/firmware/qcom
        mkdir -p $out/lib/firmware/ath12k/WCN7850/hw2.0

        # Copy GPU firmware
        cp -r ${pkgs.linux-firmware}/lib/firmware/qcom/gen70500_*.fw $out/lib/firmware/qcom/

        # Copy ath12k WiFi firmware
        cp -r ${pkgs.linux-firmware}/lib/firmware/ath12k/WCN7850/hw2.0/* $out/lib/firmware/ath12k/WCN7850/hw2.0/

        # Make files writeable so we can remove them
        chmod -R +w $out

        # Clean up text files and symlinks to satisfy Nix's broken symlinks check
        find $out -type l -exec rm -f {} +
        find $out -name "*.txt" -exec rm -f {} +
      '')
    ];
  };

  # Audio UCM2 configuration is now upstream in alsa-ucm-conf.
  # The alexVinarskis README confirms: "Works with latest upstream alsa-ucm-config"

  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
