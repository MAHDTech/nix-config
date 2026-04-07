{
  pkgs,
  lib,
  inputs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # The sd-image-aarch64.nix already includes a kernel, but we want OURS.
  boot = {
    kernelPackages =
      let
        kernelBuild = pkgs.callPackage ./kernel.nix { inherit inputs; };
      in
      lib.mkForce (pkgs.linuxPackagesFor kernelBuild);

    initrd = {
      includeDefaultModules = false;
      allowMissingModules = true;
      availableKernelModules = lib.mkForce [
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
        "btrfs"
        "usbnet"
        "cdc_ether"
        "cdc_ncm"
        "cdc_mbim"
        "rndis_host"
      ];
    };

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
  };

  # SD Image configuration
  sdImage = {
    imageName = "nixos-zenbook-installer.img";
    # Ensure the image is large enough for the system and firmware
    firmwareSize = 512; # MB
    populateFirmwareCommands = ""; # We use our own firmware logic
    populateRootCommands = "";
  };

  # Enable SSH for remote access
  services.openssh.enable = true;
  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
  };

  # Essential firmware and DTB
  hardware = {
    graphics.enable = true;
    deviceTree = {
      enable = true;
      name = "qcom/x1e80100-asus-zenbook-ux3407.dtb";
    };
    enableRedistributableFirmware = true;
    firmware = [ (pkgs.callPackage ./firmware.nix { }) ];
  };

  networking.hostName = "zenbook-installer";
  networking.hostId = "def00003";
  nixpkgs.hostPlatform = "aarch64-linux";
}
