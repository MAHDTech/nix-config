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
        # NVMe / Storage & Bus Controllers
        "nvme"
        "usb_storage"
        "usbhid"
        "uas"
        "sd_mod"
        "xhci_pci"
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
        "phy_qcom_snps_eusb2"
        "phy_qcom_eusb2_repeater"
        "phy_qcom_qmp_combo"
        "pmic_glink"
        "qcom_pmic_glink"
        "qcom_pmic_typec"

        # Filesystem and Live Media Support
        "iso9660"
        "squashfs"
        "overlay"
        "loop"
        "btrfs"
        "ext4"
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
      # Use the EL2-specialized device tree to support firmware booting in EL2 mode
      name = "qcom/x1e80100-asus-zenbook-a14-el2.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [ (pkgs.callPackage ./firmware.nix { }) ];
  };

  # Audio (Pull UCM files from the patched kernel tree)
  environment.etc."alsa/ucm2".source = "${inputs.zenbook-linux}/ucm2";

  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
