{ modulesPath, pkgs, ... }:
{
  imports = [
    ../../system/virtualisation/qemu-guest.nix
    ../../system/config/services/nixos-bootstrap
    "${modulesPath}/virtualisation/disk-image.nix"
  ];
  networking.hostName = "";
  services = {
    nixos-bootstrap.enable = true;
    journald.settings.Journal.Storage = "persistent";
    timesyncd.enable = true;
  };
  virtualisation.diskSize = 16384;
  image.format = "qcow2";
  image.baseName = "nixos-qemu";
  environment.systemPackages = with pkgs; [
    nix
    git
    python3
    bash
    coreutils
    util-linux
    systemd
    nixos-rebuild
  ];
}
