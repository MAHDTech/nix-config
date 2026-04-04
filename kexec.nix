{ config, pkgs, modulesPath, inputs, ... }:
{
  imports = [
    # Base kexec installer profile
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
    
    # Your specific hardware configuration (Kernel, DTB, Firmware)
    ./nixos/hosts/zenbook/hardware-configuration.nix
  ];

  # Networking
  networking.hostName = "zenbook-installer";
  
  # Ensure we have the right wireless tools in the installer
  environment.systemPackages = with pkgs; [
    iw
    wirelesstools
    pciutils
    usbutils
  ];

  # SSH configuration for nixos-anywhere to connect
  services.openssh.enable = true;
  
  # IMPORTANT: We need your public SSH key here. 
  # For now, I'll add a placeholder, but you should replace it or 
  # I can read it if you tell me where it is.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoOThnSe7OTzdJec62ivfkBVCzIg5Aivq+R7NzvnbSl mahdtech@zenbook"
  ];

  # Optimization: Don't build documentation in the installer to save RAM/Time
  documentation.enable = false;
  
  # Ensure the installer knows how to handle your btrfs partition
  boot.supportedFilesystems = [ "btrfs" "vfat" ];
  boot.initrd.includeDefaultModules = false;
  boot.initrd.allowMissingModules = true;

  system.stateVersion = "26.05";
}
