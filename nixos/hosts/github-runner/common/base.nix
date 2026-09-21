{ ... }:
{
  imports = [ ../../../system/virtualisation/qemu-guest.nix ];
  boot.binfmt = {
    emulatedSystems = [ "aarch64-linux" ];
    preferStaticEmulators = true;
  };
}
