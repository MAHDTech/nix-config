{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../config/services/nixos-bootstrap/completion.nix
    ../config/services/cloud-init
  ];

  boot = {
    initrd.availableKernelModules = [
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
      systemd-boot.configurationLimit = 5;
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  networking = {
    useDHCP = lib.mkDefault true;
    useNetworkd = true;
  };
  services = {
    nixos-bootstrap-completion.enable = true;
    qemuGuest.enable = true;
    cloud-init-diagnostics.enable = true;
    cloud-init = {
      # NixOS sshd generates per-VM host keys; cloud-init must not replace them.
      settings = {
        ssh_deletekeys = false;
        ssh_genkeytypes = [ ];
        ssh.emit_keys_to_console = false;
      };
      network.enable = true;
      extraPackages = [
        pkgs.nix
        pkgs.nixos-rebuild
        pkgs.git
      ];
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
  };
  # Retained after adoption for diagnostics and credential preparation tasks.
  environment.systemPackages = [ pkgs.python3 ];
  time.timeZone = "Australia/Canberra";
  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];
}
