{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ./disko-config.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "sd_mod"
      "sr_mod"
    ];
    growPartition = true;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = lib.mkForce true;
      efi.efiSysMountPoint = lib.mkForce "/boot";
    };
  };
}
