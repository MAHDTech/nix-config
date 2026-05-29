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
      availableKernelModules = [
        "nvme"
        "usb_storage"
        "usbhid"
        "xhci_pci"
        "xhci_plat_hcd"
        "dwc3"
        "dwc3_qcom"
        "uas"
        "sd_mod"
        "arm_smmu"
        "qcom_geni_se"
        "qcom_smd_regulator"
        "qcom_spmi_regulator"
        "msm"
        "i2c_hid_of"
        "i2c_hid"
        "hid_multitouch"
        "qcom_sysmon"
        "qrtr_smd"
        "pcie_qcom"
        "pci_pwrctrl_pwrseq"
        "pci_pwrctrl_core"
        "phy_qcom_qmp_usb"
        "phy_qcom_snps_eusb2"
        "phy_qcom_eusb2_repeater"
        "phy_qcom_qmp_combo"
        "typec"
        "typec_ucsi"
        "ucsi_glink"
        "pmic_glink"
        "qcom_pmic_glink"
        "qcom_pmic_typec"
        "qcom_pd_mapper"
        # ISO and Live Media Support
        "iso9660"
        "squashfs"
        "overlay"
        "loop"
        "md_mod"
        "btrfs"
        "ext4"
        # Plan B: USB Tethering drivers
        "usbnet"
        "cdc_ether"
        "cdc_ncm"
        "cdc_mbim"
        "rndis_host"
      ];
      kernelModules = [ ];
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
      name = "qcom/x1e80100-asus-zenbook-a14.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [ (pkgs.callPackage ./firmware.nix { }) ];
  };

  # Audio (Pull UCM files from the patched kernel tree)
  environment.etc."alsa/ucm2".source = "${inputs.zenbook-linux}/ucm2";

  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
