{
  pkgs,
  lib,
  inputs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  boot = {
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ./kernel.nix { inherit inputs; };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd.availableKernelModules = [
      "nvme"
      "msm"
      "ath12k"
      "usb_storage"
      "usbhid"
      "xhci_pci"
      "uas"
      "sd_mod"
      "arm_smmu"
      "qcom_geni_se"
      "qcom_smd_regulator"
      "qcom_spmi_regulator"
      "i2c_hid_of"
      "i2c_hid"
      "hid_multitouch"
      "snd_soc_x1e80100"
      "qcom_q6v5_pas"
      "qcom_sysmon"
      "qrtr_smd"
      "iso9660"
      "squashfs"
      "overlay"
      "loop"
      "md_mod"
      "usbnet"
      "cdc_ether"
      "cdc_ncm"
      "cdc_mbim"
      "rndis_host"
    ];

    kernelParams = [
      "clk_ignore_unused"
      "pd_ignore_unused"
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "earlyprintk"
      "cma=128M"
      "video=efifb"
      "fbcon=map:0"
      "arm64.nopauth"
    ];

    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
    ];
    zfs.forceImportAll = lib.mkForce false;
  };

  # Disable ZFS userspace as well
  networking.hostId = "def00003"; # Required for some ZFS-adjacent checks even if disabled
  boot.zfs.enabled = lib.mkForce false;

  hardware = {
    graphics.enable = true;
    deviceTree = {
      enable = true;
      name = "qcom/x1e80100-asus-zenbook-ux3407.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [ (pkgs.callPackage ./firmware.nix { }) ];
  };

  services.openssh.enable = true;
  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
  };
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "zenbook-iso";
}
